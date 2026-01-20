# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Processes entity exposures and builds schemas from them.
      #
      class ExposureProcessor
        include GrapeOAS::ApiModelBuilders::Concerns::OasUtilities

        def initialize(entity_class, stack:, registry:)
          @entity_class = entity_class
          @stack = stack
          @registry = registry
        end

        # Adds all exposures to a schema.
        #
        # @param schema [ApiModel::Schema] the schema to populate
        def add_exposures_to_schema(schema)
          exposures.each do |exposure|
            next unless exposed?(exposure)

            add_exposure_to_schema(schema, exposure)
          end
        end

        # Gets the exposures defined on the entity class.
        #
        # @return [Array] list of entity exposures
        def exposures
          return [] unless @entity_class.respond_to?(:root_exposures)

          root = @entity_class.root_exposures
          list = root.instance_variable_get(:@exposures) || []
          Array(list)
        rescue NoMethodError
          []
        end

        # Gets the exposures defined on a parent entity.
        #
        # @param parent_entity [Class] the parent entity class
        # @return [Array] list of parent exposures
        def parent_exposures(parent_entity)
          return [] unless parent_entity.respond_to?(:root_exposures)

          root = parent_entity.root_exposures
          list = root.instance_variable_get(:@exposures) || []
          Array(list)
        rescue NoMethodError
          []
        end

        # Builds a schema for an exposure.
        #
        # @param exposure the entity exposure
        # @param doc [Hash] the documentation hash
        # @return [ApiModel::Schema] the built schema
        def schema_for_exposure(exposure, doc)
          opts = exposure.instance_variable_get(:@options) || {}
          type = opts[:using] || doc[:type] || doc["type"]

          schema = build_exposure_base_schema(type)
          apply_exposure_properties(schema, doc)
          apply_exposure_constraints(schema, doc)
          schema
        end

        # Checks if an exposure should be included in the schema.
        #
        # @param exposure the entity exposure
        # @return [Boolean] true if exposed
        def exposed?(exposure)
          exposure.instance_variable_get(:@conditions) || []
          true
        rescue NoMethodError
          true
        end

        # Checks if an exposure is conditional.
        #
        # @param exposure the entity exposure
        # @return [Boolean] true if conditional
        def conditional?(exposure)
          conditions = exposure.instance_variable_get(:@conditions) || []
          !conditions.empty?
        rescue NoMethodError
          false
        end

        # Checks if an exposure is a merge exposure.
        #
        # @param exposure the entity exposure
        # @param doc [Hash] the documentation hash
        # @param opts [Hash] the options hash
        # @return [Boolean] true if merge exposure
        def merge_exposure?(exposure, doc, opts)
          merge_flag = PropertyExtractor.extract_merge_flag(exposure, doc, opts)
          merge_flag && resolve_entity_from_opts(exposure, doc)
        end

        private

        def add_exposure_to_schema(schema, exposure)
          doc = exposure.documentation || {}
          opts = exposure.instance_variable_get(:@options) || {}

          if merge_exposure?(exposure, doc, opts)
            merge_exposure_into_schema(schema, exposure, doc)
          else
            add_property_from_exposure(schema, exposure, doc)
          end
        end

        def merge_exposure_into_schema(schema, exposure, doc)
          merged_schema = schema_for_merge(exposure, doc)
          merged_schema.properties.each do |n, ps|
            schema.add_property(n, ps, required: merged_schema.required.include?(n))
          end
        end

        def add_property_from_exposure(schema, exposure, doc)
          prop_schema = schema_for_exposure(exposure, doc)
          required = determine_required(doc, exposure)
          prop_schema = wrap_in_array_if_needed(prop_schema, doc)
          schema.add_property(exposure.key.to_s, prop_schema, required: required)
        end

        def determine_required(doc, exposure)
          # If explicitly set in documentation, use that value
          return doc[:required] unless doc[:required].nil?

          # Conditional exposures are not required (may be absent from output)
          return false if conditional?(exposure)

          # Unconditional exposures are required by default (always present in output)
          true
        end

        def wrap_in_array_if_needed(prop_schema, doc)
          is_array = doc[:is_array] || doc["is_array"]
          return prop_schema unless is_array

          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: prop_schema)
        end

        def build_exposure_base_schema(type)
          if type.is_a?(Array)
            # Array instance like [String] - extract inner type
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
            schema_for_type(type) || ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          end
        end

        def apply_exposure_properties(schema, doc)
          schema.nullable = doc[:nullable] || doc["nullable"] || false
          schema.enum = doc[:values] || doc["values"] if doc[:values] || doc["values"]
          schema.description = doc[:desc] || doc["desc"] if doc[:desc] || doc["desc"]
          schema.format = doc[:format] || doc["format"] if doc[:format] || doc["format"]
          schema.examples = doc[:example] || doc["example"] if schema.respond_to?(:examples=) && (doc[:example] || doc["example"])
          schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
          schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)
          defs = doc[:defs] || doc[:$defs]
          schema.defs = defs if defs.is_a?(Hash)
          x_ext = extract_extensions(doc)
          schema.extensions = x_ext if x_ext && schema.respond_to?(:extensions=)
        end

        def apply_exposure_constraints(schema, doc)
          schema.minimum = doc[:minimum] if doc.key?(:minimum) && schema.respond_to?(:minimum=)
          schema.maximum = doc[:maximum] if doc.key?(:maximum) && schema.respond_to?(:maximum=)
          schema.min_length = doc[:min_length] if doc.key?(:min_length) && schema.respond_to?(:min_length=)
          schema.max_length = doc[:max_length] if doc.key?(:max_length) && schema.respond_to?(:max_length=)
          schema.pattern = doc[:pattern] if doc.key?(:pattern) && schema.respond_to?(:pattern=)
        end

        def schema_for_type(type)
          case type
          when Class
            schema_for_class_type(type)
          when String, Symbol
            schema_for_string_type(type.to_s)
          else
            default_string_schema
          end
        end

        def schema_for_class_type(type)
          if defined?(Grape::Entity) && type <= Grape::Entity
            GrapeOAS.introspectors.build_schema(type, stack: @stack, registry: @registry)
          else
            build_schema_for_primitive(type) || default_string_schema
          end
        end

        def schema_for_string_type(type_name)
          entity_class = resolve_entity_from_string(type_name)
          if entity_class
            GrapeOAS.introspectors.build_schema(entity_class, stack: @stack, registry: @registry)
          else
            schema_type = Constants.primitive_type(type_name) || Constants::SchemaTypes::STRING
            ApiModel::Schema.new(type: schema_type)
          end
        end

        def default_string_schema
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
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

        def resolve_entity_from_opts(exposure, doc)
          opts = exposure.instance_variable_get(:@options) || {}
          type = opts[:using] || doc[:type] || doc["type"]
          return type if defined?(Grape::Entity) && type.is_a?(Class) && type <= Grape::Entity

          nil
        end

        def build_schema_for_primitive(type)
          schema_type = Constants.primitive_type(type)
          return nil unless schema_type

          ApiModel::Schema.new(
            type: schema_type,
            format: Constants.format_for_type(type),
          )
        end
      end
    end
  end
end
