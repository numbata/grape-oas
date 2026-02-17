# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Reconstructs nested parameter structures from Grape's flat bracket notation.
      # Grape exposes nested params as flat keys like "address[street]", "address[city]".
      # This class converts them back to proper nested schemas.
      class NestedParamsBuilder
        BRACKET_PATTERN = /\[([^\]]+)\]/
        MAX_NESTING_DEPTH = 10

        def initialize(schema_builder:)
          @schema_builder = schema_builder
        end

        # Builds a nested schema from flat bracket-notation params.
        #
        # @param flat_params [Hash] the flat params from Grape route (name => spec)
        # @param path_params [Array<String>] names of path parameters to exclude
        # @return [ApiModel::Schema] the reconstructed nested schema
        def build(flat_params, path_params: [])
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)

          # Separate top-level params from nested bracket params
          top_level, nested = partition_params(flat_params)

          # Group nested params by their root key
          nested_groups = group_nested_params(nested)

          top_level.each do |name, spec|
            next if path_params.include?(name)
            next if ParamLocationResolver.explicit_non_body_param?(spec)
            next if ParamLocationResolver.hidden_parameter?(spec)

            child_schema = @schema_builder.build(spec)

            # Check if this param has nested children
            if nested_groups.key?(name)
              nested_children = nested_groups[name]
              child_schema = build_nested_children(spec, nested_children, depth: 0)
            end

            required = spec[:required] || false
            schema.add_property(name, child_schema, required: required)
          end

          schema
        end

        private

        # Partitions params into top-level (no brackets) and nested (with brackets).
        def partition_params(flat_params)
          top_level = {}
          nested = {}

          flat_params.each do |name, spec|
            if name.include?("[")
              nested[name] = spec
            else
              top_level[name] = spec
            end
          end

          [top_level, nested]
        end

        # Groups nested params by their root key.
        # "address[street]" => { "address" => { "street" => spec } }
        def group_nested_params(nested_params)
          groups = Hash.new { |h, k| h[k] = {} }

          nested_params.each do |name, spec|
            root, rest = parse_bracket_key(name)
            groups[root][rest] = spec
          end

          groups
        end

        # Parses a bracket-notation key into root and remaining path.
        # "address[street]" => ["address", "street"]
        # "company[address][street]" => ["company", "address[street]"]
        def parse_bracket_key(name)
          match = name.match(/^([^\[]+)\[([^\]]+)\](.*)$/)
          return [name, nil] unless match

          root = match[1]
          first_key = match[2]
          remainder = match[3]

          rest = remainder.empty? ? first_key : "#{first_key}#{remainder}"
          [root, rest]
        end

        # Builds nested children schema recursively.
        # @raise [ArgumentError] if nesting exceeds MAX_NESTING_DEPTH
        def build_nested_children(parent_spec, nested_children, depth: 0)
          raise ArgumentError, "Parameter nesting too deep (max #{MAX_NESTING_DEPTH} levels)" if depth > MAX_NESTING_DEPTH

          parent_type = parent_spec[:type]

          if array_type?(parent_type)
            build_array_with_children(parent_spec, nested_children, depth: depth)
          else
            build_hash_with_children(parent_spec, nested_children, depth: depth)
          end
        end

        # Checks if type represents an array (class or string "Array")
        def array_type?(type)
          type == Array || type.to_s == "Array"
        end

        # Builds an array schema with nested item properties.
        def build_array_with_children(parent_spec, nested_children, depth: 0)
          items_schema = build_hash_with_children(parent_spec, nested_children, depth: depth)
          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: items_schema,
          )
        end

        # Builds a hash/object schema with nested properties.
        def build_hash_with_children(parent_spec, nested_children, depth: 0)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          top_level, deeply_nested = partition_params(nested_children)
          nested_groups = group_nested_params(deeply_nested)

          top_level.each do |name, spec|
            child_schema = if nested_groups.key?(name)
                             build_nested_children(spec, nested_groups[name], depth: depth + 1)
                           else
                             @schema_builder.build(spec)
                           end
            schema.add_property(name, child_schema, required: spec[:required] || false)
          end

          apply_documentation_extensions(schema, parent_spec)
          schema
        end

        def apply_documentation_extensions(schema, parent_spec)
          doc = parent_spec[:documentation] || {}
          schema.description = doc[:desc] if doc[:desc]
          schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
          schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)
          schema.format = doc[:format] if doc[:format]
          schema.examples = doc[:example] if doc[:example]
          nullable = SchemaEnhancer.extract_nullable(parent_spec, doc)
          schema.nullable = (schema.nullable || nullable) if schema.respond_to?(:nullable=)
        end
      end
    end
  end
end
