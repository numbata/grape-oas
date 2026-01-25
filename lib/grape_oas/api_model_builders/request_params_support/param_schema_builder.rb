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
          return build_multi_type_schema(raw_type) if multi_type?(raw_type)
          return build_simple_array_schema if simple_array?(raw_type)

          # Use TypeResolvers registry for arrays, Dry::Types, and primitives
          # This resolves stringified types back to actual classes and extracts rich metadata
          resolved_schema = GrapeOAS.type_resolvers.build_schema(raw_type)
          return resolved_schema if resolved_schema

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
          items = entity_type ? GrapeOAS.introspectors.build_schema(entity_type, stack: [], registry: {}) : nil
          fallback_type = extract_entity_type_from_array(spec, raw_type)
          items ||= ApiModel::Schema.new(
            type: sanitize_type(fallback_type),
            format: Constants.format_for_type(fallback_type),
          )
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
        end

        def build_doc_entity_array_schema(doc_type)
          entity_class = resolve_entity_class(doc_type)
          items = GrapeOAS.introspectors.build_schema(entity_class, stack: [], registry: {})
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items)
        end

        def build_entity_schema(type)
          entity_class = resolve_entity_class(type)
          GrapeOAS.introspectors.build_schema(entity_class, stack: [], registry: {})
        end

        def build_elements_array_schema(spec)
          items_type = spec[:elements]
          entity = resolve_entity_class(items_type)
          items_schema = if entity
                           GrapeOAS.introspectors.build_schema(entity, stack: [], registry: {})
                         else
                           ApiModel::Schema.new(
                             type: sanitize_type(items_type),
                             format: Constants.format_for_type(items_type),
                           )
                         end
          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
        end

        def build_simple_array_schema
          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: ApiModel::Schema.new(type: Constants::SchemaTypes::STRING),
          )
        end

        # Builds schema for Grape's multi-type notation like "[String, Integer]"
        # Special case: "[Type, NilClass]" becomes a nullable Type (not oneOf)
        def build_multi_type_schema(type)
          type_names = extract_multi_types(type)

          # OPTIMIZE: [Type, Nil] becomes nullable Type instead of oneOf
          if nullable_type_pair?(type_names)
            non_nil_type = type_names.find { |t| !nil_type_name?(t) }
            return ApiModel::Schema.new(
              type: resolve_schema_type(non_nil_type),
              format: Constants.format_for_type(non_nil_type),
              nullable: true,
            )
          end

          # General case: build oneOf schema
          # Filter out nil types - OpenAPI 3.0 uses nullable property instead
          has_nil_type = type_names.any? { |t| nil_type_name?(t) }
          non_nil_types = type_names.reject { |t| nil_type_name?(t) }

          schemas = non_nil_types.map do |type_name|
            ApiModel::Schema.new(
              type: resolve_schema_type(type_name),
              format: Constants.format_for_type(type_name),
            )
          end
          ApiModel::Schema.new(one_of: schemas, nullable: has_nil_type ? true : nil)
        end

        # Checks if type_names is a pair of [SomeType, NilType]
        def nullable_type_pair?(type_names)
          return false unless type_names.size == 2

          type_names.one? { |t| nil_type_name?(t) }
        end

        # Checks if the type name represents a nil/null type
        def nil_type_name?(type_name)
          normalized = type_name.to_s
          # Match common nil type patterns:
          # - "NilClass" (Ruby's nil type)
          # - "Nil" (shorthand)
          # - "Foo::Nil", "Types::Nil" (namespaced nil types)
          normalized == "NilClass" ||
            normalized == "Nil" ||
            normalized.end_with?("::Nil")
        end

        def build_primitive_schema(raw_type, doc)
          schema_type = sanitize_type(raw_type)
          ApiModel::Schema.new(
            type: schema_type,
            format: Constants.format_for_type(raw_type),
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

        # Checks if type is a simple Array (class or string)
        def simple_array?(type)
          type == Array || type.to_s == "Array"
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
