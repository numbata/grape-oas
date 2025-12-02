# frozen_string_literal: true

require_relative "concerns/type_resolver"
require_relative "concerns/nested_params_builder"

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      include Concerns::TypeResolver
      include Concerns::NestedParamsBuilder

      ROUTE_PARAM_REGEX = /(?<=:)\w+/
      VALID_CONSTANT_PATTERN = /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*\z/

      attr_reader :api, :route, :path_param_name_map

      def initialize(api:, route:, path_param_name_map: nil)
        @api = api
        @route = route
        @path_param_name_map = path_param_name_map || {}
      end

      def build
        route_params = route.path.scan(ROUTE_PARAM_REGEX)
        all_params = route.options[:params] || {}

        # Check if we have nested params (bracket notation)
        has_nested = all_params.keys.any? { |k| k.include?("[") }

        if has_nested
          build_with_nested_params(all_params, route_params)
        else
          build_flat_params(all_params, route_params)
        end
      end

      private

      # Builds params when nested structures are detected.
      def build_with_nested_params(all_params, route_params)
        body_schema = build_nested_schema(all_params, path_params: route_params)
        non_body_params = extract_non_body_params(all_params, route_params)

        [body_schema, non_body_params]
      end

      # Builds params for flat (non-nested) structures.
      def build_flat_params(all_params, route_params)
        body_schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        path_params = []

        all_params.each do |name, spec|
          location = route_params.include?(name) ? "path" : extract_location(spec: spec)
          required = spec[:required] || false
          schema = build_schema_for_spec(spec)
          mapped_name = path_param_name_map.fetch(name, name)

          if location == "body"
            body_schema.add_property(name, schema, required: required)
          else
            path_params << GrapeOAS::ApiModel::Parameter.new(
              location: location,
              name: mapped_name,
              required: required,
              schema: schema,
              description: spec[:documentation]&.dig(:desc),
              collection_format: extract_collection_format(spec),
            )
          end
        end

        [body_schema, path_params]
      end

      # Extracts non-body params (path, query, header) from flat params.
      def extract_non_body_params(all_params, route_params)
        params = []

        all_params.each do |name, spec|
          # Skip nested params (they go into body)
          next if name.include?("[")
          # Skip Hash/body params
          next if body_param?(spec)

          location = route_params.include?(name) ? "path" : extract_location(spec: spec)
          next if location == "body"

          mapped_name = path_param_name_map.fetch(name, name)
          params << GrapeOAS::ApiModel::Parameter.new(
            location: location,
            name: mapped_name,
            required: spec[:required] || false,
            schema: build_schema_for_spec(spec),
            description: spec[:documentation]&.dig(:desc),
            collection_format: extract_collection_format(spec),
          )
        end

        params
      end

      def extract_collection_format(spec)
        spec.dig(:documentation, :collectionFormat) || spec.dig(:documentation, :collection_format)
      end

      def extract_location(spec:)
        spec.dig(:documentation, :param_type)&.downcase || "query"
      end

      def build_schema_for_spec(spec)
        doc = spec[:documentation] || {}
        raw_type = spec[:type] || doc[:type]
        nullable = extract_nullable(spec, doc)

        schema = build_base_schema_for_spec(spec, doc, raw_type)
        apply_schema_enhancements(schema, doc, nullable)
        schema
      end

      def build_base_schema_for_spec(spec, doc, raw_type)
        type_source = spec[:type]
        doc_type = doc[:type]

        return build_entity_array_schema(spec, raw_type, doc_type) if entity_array_type?(type_source, doc_type, spec)
        return build_doc_entity_array_schema(doc_type) if doc[:is_array] && grape_entity?(doc_type)
        return build_entity_schema(doc_type) if grape_entity?(doc_type)
        return build_entity_schema(raw_type) if grape_entity?(raw_type)
        return build_elements_array_schema(spec) if array_with_elements?(raw_type, spec)
        return build_typed_array_schema(raw_type) if typed_array?(raw_type)
        return build_simple_array_schema if simple_array?(raw_type)

        build_primitive_schema(raw_type, doc)
      end

      def entity_array_type?(type_source, doc_type, spec)
        (type_source == Array || type_source.to_s == "Array") &&
          grape_entity?(doc_type || spec[:elements] || spec[:of])
      end

      def array_with_elements?(raw_type, spec)
        (raw_type == Array || raw_type.to_s == "Array") && spec[:elements]
      end

      def build_entity_array_schema(spec, raw_type, doc_type)
        entity_type = resolve_entity_class(extract_entity_type_from_array(spec, raw_type, doc_type))
        items = entity_type ? GrapeOAS::Introspectors::EntityIntrospector.new(entity_type).build_schema : nil
        items ||= GrapeOAS::ApiModel::Schema.new(type: sanitize_type(extract_entity_type_from_array(spec, raw_type)))
        GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
      end

      def build_doc_entity_array_schema(doc_type)
        entity_class = resolve_entity_class(doc_type)
        items = GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
        GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
      end

      def build_entity_schema(type)
        entity_class = resolve_entity_class(type)
        GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
      end

      def build_elements_array_schema(spec)
        items_type = spec[:elements]
        entity = resolve_entity_class(items_type)
        items_schema = if entity
                         GrapeOAS::Introspectors::EntityIntrospector.new(entity).build_schema
                       else
                         GrapeOAS::ApiModel::Schema.new(type: sanitize_type(items_type))
                       end
        GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
      end

      def build_simple_array_schema
        GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::ARRAY,
          items: GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::STRING),
        )
      end

      def build_primitive_schema(raw_type, doc)
        GrapeOAS::ApiModel::Schema.new(
          type: sanitize_type(raw_type),
          description: doc[:desc],
        )
      end

      def apply_schema_enhancements(schema, doc, nullable)
        schema.description ||= doc[:desc]
        schema.nullable = nullable if schema.respond_to?(:nullable=)
        apply_additional_properties(schema, doc)
        apply_format_and_example(schema, doc)
        apply_constraints(schema, doc)
      end

      def apply_additional_properties(schema, doc)
        if doc.key?(:additional_properties) && schema.respond_to?(:additional_properties=)
          schema.additional_properties = doc[:additional_properties]
        end
        if doc.key?(:unevaluated_properties) && schema.respond_to?(:unevaluated_properties=)
          schema.unevaluated_properties = doc[:unevaluated_properties]
        end
        defs = extract_defs(doc)
        schema.defs = defs if defs.is_a?(Hash) && schema.respond_to?(:defs=)
      end

      def apply_format_and_example(schema, doc)
        schema.format = doc[:format] if doc[:format] && schema.respond_to?(:format=)
        schema.examples = doc[:example] if doc[:example] && schema.respond_to?(:examples=)
      end

      def apply_constraints(schema, doc)
        schema.minimum = doc[:minimum] if doc.key?(:minimum) && schema.respond_to?(:minimum=)
        schema.maximum = doc[:maximum] if doc.key?(:maximum) && schema.respond_to?(:maximum=)
        schema.min_length = doc[:min_length] if doc.key?(:min_length) && schema.respond_to?(:min_length=)
        schema.max_length = doc[:max_length] if doc.key?(:max_length) && schema.respond_to?(:max_length=)
        schema.pattern = doc[:pattern] if doc.key?(:pattern) && schema.respond_to?(:pattern=)
      end

      # Extract nullable flag from spec and documentation, supporting multiple key names
      def extract_nullable(spec, doc)
        spec[:allow_nil] || spec[:nullable] || doc[:nullable] || false
      end

      # Extract defs from documentation, supporting multiple key names
      def extract_defs(doc)
        doc[:defs] || doc[:$defs]
      end

      def grape_entity?(type)
        !!resolve_entity_class(type)
      end

      def extract_entity_type_from_array(spec, raw_type, doc_type = nil)
        return spec[:elements] if grape_entity?(spec[:elements])
        return spec[:of] if grape_entity?(spec[:of])
        return doc_type if grape_entity?(doc_type)

        raw_type
      end

      def sanitize_type(type)
        return Constants::SchemaTypes::OBJECT if grape_entity?(type)

        resolve_schema_type(type)
      end

      # Checks if type is a Grape typed array notation like "[String]"
      def typed_array?(type)
        type.is_a?(String) && type.match?(TYPED_ARRAY_PATTERN)
      end

      # Checks if type is a simple Array (class or string)
      def simple_array?(type)
        type == Array || type.to_s == "Array"
      end

      # Builds schema for Grape's typed array notation like "[String]", "[Integer]"
      def build_typed_array_schema(type)
        member_type = extract_typed_array_member(type)
        items_type = resolve_schema_type(member_type)
        GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::ARRAY,
          items: GrapeOAS::ApiModel::Schema.new(type: items_type),
        )
      end

      def resolve_entity_class(type)
        return nil unless defined?(Grape::Entity)
        return type if type.is_a?(Class) && type <= Grape::Entity
        return nil unless type.is_a?(String) || type.is_a?(Symbol)

        const_name = type.to_s
        return nil unless const_name.match?(VALID_CONSTANT_PATTERN)
        return nil unless Object.const_defined?(const_name, false)

        klass = Object.const_get(const_name, false)
        klass if klass.is_a?(Class) && klass <= Grape::Entity
      end
    end
  end
end
