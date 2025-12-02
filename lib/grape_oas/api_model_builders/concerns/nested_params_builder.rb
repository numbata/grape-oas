# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Reconstructs nested parameter structures from Grape's flat bracket notation.
      # Grape exposes nested params as flat keys like "address[street]", "address[city]".
      # This module converts them back to proper nested schemas.
      # rubocop:disable Metrics/ModuleLength
      module NestedParamsBuilder
        BRACKET_PATTERN = /\[([^\]]+)\]/

        # Builds a nested schema from flat bracket-notation params.
        # @param flat_params [Hash] The flat params from Grape route (name => spec)
        # @param path_params [Array<String>] Names of path parameters to exclude
        # @return [ApiModel::Schema] The reconstructed nested schema
        def build_nested_schema(flat_params, path_params: [])
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)

          # Separate top-level params from nested bracket params
          top_level, nested = partition_params(flat_params)

          # Group nested params by their root key
          nested_groups = group_nested_params(nested)

          top_level.each do |name, spec|
            # Skip path params and explicitly non-body params
            next if path_params.include?(name)
            next if explicit_non_body_param?(spec)

            child_schema = build_schema_for_spec(spec)

            # Check if this param has nested children
            if nested_groups.key?(name)
              # It's a container (Hash or Array) with children
              nested_children = nested_groups[name]
              child_schema = build_nested_children(spec, nested_children)
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
        def build_nested_children(parent_spec, nested_children)
          parent_type = parent_spec[:type]

          if array_type?(parent_type)
            build_array_with_children(parent_spec, nested_children)
          else
            build_hash_with_children(parent_spec, nested_children)
          end
        end

        # Checks if type represents an array (class or string "Array")
        def array_type?(type)
          type == Array || type.to_s == "Array"
        end

        # Builds an array schema with nested item properties.
        def build_array_with_children(parent_spec, nested_children)
          items_schema = build_hash_with_children(parent_spec, nested_children)
          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: items_schema,
          )
        end

        # Builds a hash/object schema with nested properties.
        def build_hash_with_children(parent_spec, nested_children)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)

          # Process nested children which may themselves be nested
          flat_for_recursion = unflatten_one_level(nested_children)
          top_level, deeply_nested = partition_params(flat_for_recursion)
          nested_groups = group_nested_params(deeply_nested)

          top_level.each do |name, spec|
            child_schema = if nested_groups.key?(name)
                             build_nested_children(spec, nested_groups[name])
                           else
                             build_schema_for_spec(spec)
                           end

            required = spec[:required] || false
            schema.add_property(name, child_schema, required: required)
          end

          apply_documentation_extensions(schema, parent_spec)
          schema
        end

        # Converts nested_children hash to flat format for recursion.
        # { "street" => spec1, "city[zip]" => spec2 } stays as is
        def unflatten_one_level(nested_children)
          nested_children
        end

        # Applies any documentation extensions from parent spec.
        def apply_documentation_extensions(schema, parent_spec)
          doc = parent_spec[:documentation] || {}
          schema.description = doc[:desc] if doc[:desc]
        end

        # Checks if a param is explicitly marked as NOT a body param (e.g., query, header).
        def explicit_non_body_param?(spec)
          doc = spec[:documentation] || {}
          param_type = doc[:param_type]&.to_s&.downcase
          param_type && %w[query header path].include?(param_type)
        end

        # Checks if a param should be in the body.
        def body_param?(spec)
          doc = spec[:documentation] || {}
          doc[:param_type] == "body" ||
            spec[:type].to_s == "Hash" ||
            spec[:type] == Hash
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
