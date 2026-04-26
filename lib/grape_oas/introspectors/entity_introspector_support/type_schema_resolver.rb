# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Resolves OpenAPI schemas from Grape Entity exposure types.
      # Handles primitives, Grape::Entity subclasses (via recursive introspection),
      # and merge exposures. Extracted from ExposureProcessor so the type-resolution
      # concern can be read and tested in isolation.
      class TypeSchemaResolver
        include GrapeOAS::ApiModelBuilders::Concerns::OasUtilities

        def initialize(stack:, registry:)
          @stack = stack
          @registry = registry
        end

        # Builds the base schema for an exposure's type annotation.
        # Handles array literals, the Array class, Hash, and all scalar types.
        #
        # @param type [Class, Array, String, Symbol, nil] the type annotation
        # @return [ApiModel::Schema]
        def build_exposure_base_schema(type)
          if type.is_a?(Array)
            inner = schema_for_type(type.first)
            ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: inner)
          elsif type == Array
            # Array class itself - create array with string items
            ApiModel::Schema.new(
              type: Constants::SchemaTypes::ARRAY,
              items: ApiModel::Schema.new(type: Constants::SchemaTypes::STRING),
            )
          elsif type.is_a?(Hash) || type == Hash
            ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          else
            schema_for_type(type)
          end
        end

        # Builds and returns a flattened object schema from the merge-target entity.
        # Returns an empty object schema when no entity can be resolved.
        #
        # @param exposure the entity exposure
        # @param doc [Hash] normalized documentation hash
        # @return [ApiModel::Schema]
        def schema_for_merge(exposure, doc)
          using_class = resolve_entity_from_opts(exposure, doc)
          return ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT) unless using_class

          child = GrapeOAS.introspectors.build_schema(using_class, stack: @stack, registry: @registry)
          merged = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          child.properties.each do |n, ps|
            merged.add_property(n, ps, required: child.required.include?(n))
          end
          merged
        end

        # Resolves the Grape::Entity class referenced by an exposure's options or doc.
        #
        # @param exposure the entity exposure
        # @param doc [Hash] normalized documentation hash
        # @return [Class, nil] the entity class or nil
        def resolve_entity_from_opts(exposure, doc)
          opts = exposure.instance_variable_get(:@options) || {}
          resolve_grape_entity_class(opts, doc)
        end

        # Checks if opts or doc point to a Grape::Entity subclass.
        #
        # @param opts [Hash] exposure options
        # @param doc [Hash] normalized documentation hash
        # @return [Class, nil] the entity class or nil
        def resolve_grape_entity_class(opts, doc)
          type = opts[:using] || doc[:type]
          return type if defined?(Grape::Entity) && type.is_a?(Class) && type <= Grape::Entity

          nil
        end

        private

        def schema_for_type(type)
          case type
          when Class
            schema_for_class_type(type)
          when String, Symbol
            schema_for_string_type(type.to_s)
          else
            GrapeOAS.type_resolvers.build_schema(type)
          end
        end

        def schema_for_class_type(type)
          if defined?(Grape::Entity) && type <= Grape::Entity
            GrapeOAS.introspectors.build_schema(type, stack: @stack, registry: @registry)
          else
            GrapeOAS.type_resolvers.build_schema(type)
          end
        end

        def schema_for_string_type(type_name)
          entity_class = resolve_entity_from_string(type_name)
          if entity_class
            GrapeOAS.introspectors.build_schema(entity_class, stack: @stack, registry: @registry)
          else
            GrapeOAS.type_resolvers.build_schema(type_name)
          end
        end

        def resolve_entity_from_string(type_name)
          return nil unless defined?(Grape::Entity)
          return nil unless valid_constant_name?(type_name)
          return nil unless Object.const_defined?(type_name, false)

          klass = Object.const_get(type_name, false)
          klass if klass.is_a?(Class) && klass <= Grape::Entity
        rescue NameError
          nil
        end
      end
    end
  end
end
