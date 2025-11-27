# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      ROUTE_PARAM_REGEX = /(?<=:)\w+/

      PRIMITIVE_TYPE_MAPPING = {
        "float" => "number",
        "bigdecimal" => "number",
        "string" => "string",
        "integer" => "integer",
        "boolean" => "boolean",
        "grape::api::boolean" => "boolean",
        "trueclass" => "boolean",
        "falseclass" => "boolean"
      }.freeze

      attr_reader :api, :route, :path_param_name_map

      def initialize(api:, route:, path_param_name_map: nil)
        @api = api
        @route = route
        @path_param_name_map = path_param_name_map || {}
      end

      def build
        route_params = route.path.scan(ROUTE_PARAM_REGEX)

        body_schema = GrapeOAS::ApiModel::Schema.new(type: "object")
        path_params = []

        (route.options[:params] || {}).each do |name, spec|
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

      private

      def extract_location(spec:)
        spec.dig(:documentation, :param_type)&.downcase || "query"
      end

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
                   GrapeOAS::ApiModel::Schema.new(type: "array", items: items)
                 elsif doc[:is_array] && grape_entity?(doc_type)
                   entity_class = resolve_entity_class(doc_type)
                   items = GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                   GrapeOAS::ApiModel::Schema.new(type: "array", items: items)
                 elsif grape_entity?(doc_type)
                   entity_class = resolve_entity_class(doc_type)
                   GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                 elsif grape_entity?(raw_type)
                   entity_class = resolve_entity_class(raw_type)
                   GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
                 elsif raw_type == Array && spec[:elements]
                   items_type = spec[:elements]
                   entity = resolve_entity_class(items_type)
                   items_schema = if entity
                                    GrapeOAS::Introspectors::EntityIntrospector.new(entity).build_schema
                                  else
                                    GrapeOAS::ApiModel::Schema.new(type: sanitize_type(items_type))
                                  end
                   GrapeOAS::ApiModel::Schema.new(type: "array", items: items_schema)
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
        return "object" if grape_entity?(type)

        type = type.to_s if type.is_a?(Symbol)
        case type
        when Integer
          "integer"
        when Float, BigDecimal
          "number"
        when TrueClass, FalseClass
          "boolean"
        when Array
          "array"
        when Hash
          "object"
        else
          PRIMITIVE_TYPE_MAPPING.fetch(type.to_s.downcase, "string")
        end
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
