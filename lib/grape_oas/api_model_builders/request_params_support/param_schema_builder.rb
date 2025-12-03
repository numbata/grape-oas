# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Builds OpenAPI schemas from Grape parameter specifications.
      class ParamSchemaBuilder
        include Concerns::TypeResolver
        include Concerns::OasUtilities

        # Builds a schema for a parameter specification.
        #
        # @param spec [Hash] the parameter specification
        # @return [ApiModel::Schema] the built schema
        def self.build(spec)
          new.build(spec)
        end

        def build(spec)
          doc = spec[:documentation] || {}
          raw_type = spec[:type] || doc[:type]

          schema = build_base_schema(spec, doc, raw_type)
          SchemaEnhancer.apply(schema, spec, doc)
          schema
        end

        private

        def build_base_schema(spec, doc, raw_type)
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
          items = entity_type ? Introspectors::EntityIntrospector.new(entity_type).build_schema : nil
          items ||= ApiModel::Schema.new(type: sanitize_type(extract_entity_type_from_array(spec, raw_type)))
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
        end

        def build_doc_entity_array_schema(doc_type)
          entity_class = resolve_entity_class(doc_type)
          items = Introspectors::EntityIntrospector.new(entity_class).build_schema
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
        end

        def build_entity_schema(type)
          entity_class = resolve_entity_class(type)
          Introspectors::EntityIntrospector.new(entity_class).build_schema
        end

        def build_elements_array_schema(spec)
          items_type = spec[:elements]
          entity = resolve_entity_class(items_type)
          items_schema = if entity
                           Introspectors::EntityIntrospector.new(entity).build_schema
                         else
                           ApiModel::Schema.new(type: sanitize_type(items_type))
                         end
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
        end

        def build_simple_array_schema
          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: ApiModel::Schema.new(type: Constants::SchemaTypes::STRING),
          )
        end

        def build_primitive_schema(raw_type, doc)
          ApiModel::Schema.new(
            type: sanitize_type(raw_type),
            description: doc[:desc],
          )
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

        def grape_entity?(type)
          !!resolve_entity_class(type)
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
          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: ApiModel::Schema.new(type: items_type),
          )
        end

        def resolve_entity_class(type)
          return nil unless defined?(Grape::Entity)
          return type if type.is_a?(Class) && type <= Grape::Entity
          return nil unless type.is_a?(String) || type.is_a?(Symbol)

          const_name = type.to_s
          return nil unless valid_constant_name?(const_name)
          return nil unless Object.const_defined?(const_name, false)

          klass = Object.const_get(const_name, false)
          klass if klass.is_a?(Class) && klass <= Grape::Entity
        rescue NameError => e
          warn "[grape-oas] Could not resolve entity constant '#{const_name}': #{e.message}"
          nil
        end
      end
    end
  end
end
