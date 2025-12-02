# frozen_string_literal: true

require_relative "concerns/type_resolver"
require_relative "concerns/nested_params_builder"

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      include Concerns::TypeResolver
      include Concerns::NestedParamsBuilder

      ROUTE_PARAM_REGEX = /(?<=:)\w+/

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
          )
        end

        params
      end

      def extract_location(spec:)
        spec.dig(:documentation, :param_type)&.downcase || "query"
      end

      # rubocop:disable Metrics/AbcSize
      def build_schema_for_spec(spec)
        doc = spec[:documentation] || {}
        type_source = spec[:type]
        doc_type = doc[:type]
        raw_type = type_source || doc_type
        nullable = extract_nullable(spec, doc)

        schema = if (type_source == Array || type_source.to_s == "Array") && grape_entity?(doc_type || spec[:elements] || spec[:of])
                   entity_type = resolve_entity_class(extract_entity_type_from_array(spec, raw_type, doc_type))
                   items = GrapeOAS::Introspectors::EntityIntrospector.new(entity_type).build_schema if entity_type
                   items ||= GrapeOAS::ApiModel::Schema.new(type: sanitize_type(extract_entity_type_from_array(spec,
                                                                                                               raw_type,)))
                   GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
                 elsif doc[:is_array] && grape_entity?(doc_type)
                   entity_class = resolve_entity_class(doc_type)
                   items = GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                   GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
                 elsif grape_entity?(doc_type)
                   entity_class = resolve_entity_class(doc_type)
                   GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                 elsif grape_entity?(raw_type)
                   entity_class = resolve_entity_class(raw_type)
                   GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                 elsif (raw_type == Array || raw_type.to_s == "Array") && spec[:elements]
                   items_type = spec[:elements]
                   entity = resolve_entity_class(items_type)
                   items_schema = if entity
                                    GrapeOAS::Introspectors::EntityIntrospector.new(entity).build_schema
                                  else
                                    GrapeOAS::ApiModel::Schema.new(type: sanitize_type(items_type))
                                  end
                   GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
                 elsif typed_array?(raw_type)
                   # Handle Grape's "[Type]" notation like "[String]", "[Integer]"
                   build_typed_array_schema(raw_type)
                 elsif simple_array?(raw_type)
                   # Handle plain Array type without nested children
                   GrapeOAS::ApiModel::Schema.new(
                     type: Constants::SchemaTypes::ARRAY,
                     items: GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::STRING),
                   )
                 else
                   GrapeOAS::ApiModel::Schema.new(
                     type: sanitize_type(raw_type),
                     description: doc[:desc],
                     nullable: nullable,
                   )
                 end

        schema.description ||= doc[:desc]
        schema.nullable = nullable if schema.respond_to?(:nullable=)
        if doc.key?(:additional_properties) && schema.respond_to?(:additional_properties=)
          schema.additional_properties = doc[:additional_properties]
        end
        if doc.key?(:unevaluated_properties) && schema.respond_to?(:unevaluated_properties=)
          schema.unevaluated_properties = doc[:unevaluated_properties]
        end
        defs = extract_defs(doc)
        schema.defs = defs if defs.is_a?(Hash) && schema.respond_to?(:defs=)
        schema
      end
      # rubocop:enable Metrics/AbcSize

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
        return type if defined?(Grape::Entity) && type.is_a?(Class) && type <= Grape::Entity
        return nil unless type.is_a?(String) || type.is_a?(Symbol)

        const_name = type.to_s
        if Object.const_defined?(const_name) &&
           Object.const_get(const_name).is_a?(Class) &&
           Object.const_get(const_name) <= (defined?(Grape::Entity) ? Grape::Entity : Object)
          Object.const_get(const_name)
        end
      rescue NameError
        nil
      end
    end
  end
end
