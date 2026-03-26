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
          EntityIntrospectorSupport.exposures(@entity_class)
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
        # @param doc [Hash] the documentation hash (must be normalized via normalize_doc_keys)
        # @return [ApiModel::Schema] the built schema
        def schema_for_exposure(exposure, doc)
          opts = exposure_options(exposure)
          type = opts[:using] || doc[:type]

          schema = type_resolver.build_exposure_base_schema(type)
          apply_exposure_properties(schema, doc)
          SchemaConstraints.apply(schema, doc)
          schema
        end

        # Builds the property schema for an exposure, routing nesting exposures
        # to the inline-object path. Wraps in array if doc[:is_array] is set.
        # Doc must already be normalized via normalize_doc_keys.
        #
        # @param exposure the entity exposure
        # @param doc [Hash] normalized documentation hash
        # @return [ApiModel::Schema]
        def build_property_schema(exposure, doc)
          prop_schema = if nesting_exposure?(exposure)
                          build_nesting_exposure_schema(exposure, doc)
                        else
                          schema_for_exposure(exposure, doc)
                        end
          wrap_in_array_if_needed(prop_schema, doc)
        end

        # Checks if an exposure should be included in the schema.
        # All exposures are currently included; this hook exists for future
        # filtering logic (e.g. conditionals, feature flags).
        #
        # @param exposure the entity exposure
        # @return [Boolean] true if exposed
        def exposed?(_exposure)
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
          merge_flag && type_resolver.resolve_entity_from_opts(exposure, doc)
        end

        # Returns the options hash for an exposure.
        #
        # @param exposure the entity exposure
        # @return [Hash]
        def exposure_options(exposure)
          exposure.instance_variable_get(:@options) || {}
        end

        # Determines whether a property should be marked required.
        # Explicit doc[:required] takes precedence; conditional exposures
        # default to false; unconditional exposures default to true.
        #
        # @param doc [Hash] normalized documentation hash
        # @param exposure the entity exposure
        # @return [Boolean]
        def determine_required(doc, exposure)
          # If explicitly set in documentation, use that value
          return doc[:required] unless doc[:required].nil?

          # Conditional exposures are not required (may be absent from output)
          return false if conditional?(exposure)

          # Unconditional exposures are required by default (always present in output)
          true
        end

        private

        def type_resolver
          @type_resolver ||= TypeSchemaResolver.new(stack: @stack, registry: @registry)
        end

        def add_exposure_to_schema(schema, exposure)
          doc = exposure.documentation || {}
          opts = exposure_options(exposure)

          if merge_exposure?(exposure, doc, opts)
            merge_exposure_into_schema(schema, exposure, doc)
          else
            add_property_from_exposure(schema, exposure, doc)
          end
        end

        def merge_exposure_into_schema(schema, exposure, doc)
          merged_schema = type_resolver.schema_for_merge(exposure, doc)
          merged_schema.properties.each do |n, ps|
            schema.add_property(n, ps, required: merged_schema.required.include?(n))
          end
        end

        def add_property_from_exposure(schema, exposure, doc)
          doc = normalize_doc_keys(doc)
          prop_schema = build_property_schema(exposure, doc)
          required = determine_required(doc, exposure)
          schema.add_property(exposure.key.to_s, prop_schema, required: required)
        end

        def wrap_in_array_if_needed(prop_schema, doc)
          is_array = doc[:is_array]
          return prop_schema unless is_array

          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: prop_schema)
        end

        # Detects block-based nesting exposures (NestingExposure) that should become
        # inline object schemas. Only triggers when no entity class is via `using:`.
        def nesting_exposure?(exposure)
          return false unless exposure.respond_to?(:nesting?) && exposure.nesting?

          doc = normalize_doc_keys(exposure.documentation || {})
          opts = exposure_options(exposure)
          # Extra !opts[:using] catches using: set to a non-entity class (e.g. String)
          !type_resolver.resolve_grape_entity_class(opts, doc) && !opts[:using]
        end

        # Builds an inline object schema from a NestingExposure's child exposures.
        # Duplicate-key children (conditional branches) are merged via NestingMerger.
        def build_nesting_exposure_schema(exposure, doc)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          return schema unless exposure.respond_to?(:nested_exposures)

          nesting_accum = {}
          nesting_required = Hash.new { |h, k| h[k] = [] }
          Array(exposure.nested_exposures).each do |child_exposure|
            if nesting_exposure?(child_exposure)
              key = child_exposure.key.to_s
              child_doc = normalize_doc_keys(child_exposure.documentation || {})
              child_schema = build_property_schema(child_exposure, child_doc)
              nesting_required[key] << determine_required(child_doc, child_exposure)
              nesting_accum[key] = NestingMerger.merge(nesting_accum[key], child_schema)
            else
              add_exposure_to_schema(schema, child_exposure)
            end
          end

          # ALL branches must agree for the property to be required.
          nesting_accum.each do |key, merged_schema|
            schema.add_property(key, merged_schema, required: nesting_required[key].all?)
          end

          apply_exposure_properties(schema, doc)
          SchemaConstraints.apply(schema, doc)
          schema
        end

        def apply_exposure_properties(schema, doc)
          schema.nullable = doc[:nullable] || false
          raw_values = doc[:values]
          if raw_values
            normalized = ValuesNormalizer.normalize(raw_values, context: "entity exposure values")
            if normalized.is_a?(Array) && !normalized.empty?
              apply_enum_to_schema(schema, normalized)
            elsif normalized.is_a?(Range)
              RangeUtils.apply_to_schema(schema, normalized)
            end
          end
          schema.description = doc[:desc] if doc[:desc]
          schema.format = doc[:format] if doc[:format]
          schema.examples = doc[:example] if schema.respond_to?(:examples=) && doc[:example]
          schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
          schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)
          defs = doc[:defs] || doc[:$defs]
          schema.defs = defs if defs.is_a?(Hash)
          x_ext = extract_extensions(doc)
          schema.extensions = x_ext if x_ext && schema.respond_to?(:extensions=)
        end

        # Cached entity schemas (via using:) are shared across all exposures that
        # reference the same entity — do not mutate their enum.
        def apply_enum_to_schema(schema, values)
          return if schema.respond_to?(:canonical_name) && schema.canonical_name

          if schema.type == Constants::SchemaTypes::ARRAY &&
             schema.respond_to?(:items) && schema.items &&
             !(schema.items.respond_to?(:canonical_name) && schema.items.canonical_name)
            schema.items.enum = values
          else
            schema.enum = values
          end
        end

        def normalize_doc_keys(doc)
          DocKeyNormalizer.normalize(doc)
        end
      end
    end
  end
end
