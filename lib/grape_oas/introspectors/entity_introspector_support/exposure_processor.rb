# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Processes entity exposures and builds schemas from them.
      #
      class ExposureProcessor
        include GrapeOAS::ApiModelBuilders::Concerns::OasUtilities

        # Maximum recursion depth for merging nested object branches.
        MAX_MERGE_DEPTH = 10

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
          SchemaConstraints.apply(schema, doc.transform_keys(&:to_sym))
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
          prop_schema = if nesting_exposure?(exposure)
                          build_nesting_exposure_schema(exposure, doc)
                        else
                          schema_for_exposure(exposure, doc)
                        end
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

        # Detects block-based nesting exposures (Grape::Entity::Exposure::NestingExposure).
        # These wrap child exposures that should become properties of an inline object schema.
        # Only triggers when no entity class is referenced via `using:`.
        def nesting_exposure?(exposure)
          return false unless exposure.respond_to?(:nesting?) && exposure.nesting?

          # If using: points to an entity class, let the normal entity introspection handle it
          opts = exposure.instance_variable_get(:@options) || {}
          !resolve_entity_from_opts(exposure, exposure.documentation || {}) && !opts[:using]
        end

        # Builds an inline object schema from a NestingExposure's child exposures.
        # Recursively processes children, preserving their enum values and other properties.
        # When multiple children share the same key (conditional branches), their object
        # properties are merged rather than overwritten.
        def build_nesting_exposure_schema(exposure, doc)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)

          # Accumulate nesting-branch schemas per key so interleaved non-nesting
          # exposures don't discard earlier nesting properties.
          nesting_accum = {}
          nesting_required = Hash.new { |h, k| h[k] = [] }
          exposure.nested_exposures.each do |child_exposure|
            key = child_exposure.key.to_s
            add_exposure_to_schema(schema, child_exposure)
            next unless nesting_exposure?(child_exposure)

            nesting_required[key] << schema.required.include?(key)
            current = schema.properties[key]
            nesting_accum[key] = merge_nesting_branch(nesting_accum[key], current)
            schema.properties[key] = nesting_accum[key]
          end

          # Reconcile parent-level required for merged nesting keys:
          # a key is required only if ALL branches agree it is required.
          nesting_required.each do |key, flags|
            schema.required.delete(key) unless flags.all?
          end

          apply_exposure_properties(schema, doc)
          apply_exposure_constraints(schema, doc)
          schema
        end

        # Folds a new nesting-branch object schema into the accumulated result.
        # Uses required intersection so branch-specific fields stay optional.
        # Creates a fresh schema to avoid mutating cached canonical schemas.
        def merge_nesting_branch(accum, current, depth = 0)
          return current unless accum
          return accum if current.equal?(accum)

          # Unwrap array schemas to merge their items, then re-wrap
          if accum.type == Constants::SchemaTypes::ARRAY && current&.type == Constants::SchemaTypes::ARRAY &&
             accum.items&.type == Constants::SchemaTypes::OBJECT && current.items&.type == Constants::SchemaTypes::OBJECT
            merged_items = merge_nesting_branch(accum.items, current.items, depth)
            return ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: merged_items)
          end

          return accum unless current&.type == Constants::SchemaTypes::OBJECT
          return current unless accum.type == Constants::SchemaTypes::OBJECT

          shared_required = accum.required & current.required
          merged = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          copy_branch_metadata(merged, accum)
          copy_branch_metadata(merged, current)
          accum.properties.each do |n, s|
            merged.add_property(n, s, required: shared_required.include?(n))
          end
          current.properties.each do |n, s|
            existing = merged.properties[n]
            if existing && mergeable_schemas?(existing, s)
              if depth < MAX_MERGE_DEPTH
                merged.properties[n] = merge_nesting_branch(existing, s, depth + 1)
              else
                warn "[grape-oas] Maximum nesting merge depth (#{MAX_MERGE_DEPTH}) exceeded for property '#{n}'; skipping deep merge"
                merged.add_property(n, s, required: shared_required.include?(n))
              end
            else
              merged.add_property(n, s, required: shared_required.include?(n))
            end
          end
          merged
        end

        # Copies non-property scalar metadata from a branch schema to the merged result.
        # Called twice (accum then current) so later branch values win (last-one-wins).
        def copy_branch_metadata(merged, source)
          merged.description = source.description if source.description
          merged.nullable = source.nullable unless source.nullable.nil?
          merged.format = source.format if source.format
          merged.examples = source.examples if source.respond_to?(:examples) && source.examples
          return unless source.respond_to?(:extensions) && source.extensions

          merged.extensions = Marshal.load(Marshal.dump(source.extensions))
        end

        # Checks if two schemas can be recursively merged (both objects, or both arrays of objects).
        def mergeable_schemas?(left, right)
          return true if left.type == Constants::SchemaTypes::OBJECT && right.type == Constants::SchemaTypes::OBJECT
          return true if left.type == Constants::SchemaTypes::ARRAY && right.type == Constants::SchemaTypes::ARRAY &&
                         left.items&.type == Constants::SchemaTypes::OBJECT && right.items&.type == Constants::SchemaTypes::OBJECT

          false
        end

        def apply_exposure_properties(schema, doc)
          schema.nullable = doc[:nullable] || doc["nullable"] || false
          raw_values = doc[:values] || doc["values"]
          if raw_values
            normalized = ValuesNormalizer.normalize(raw_values, context: "entity exposure values")
            # Entity exposures do not support oneOf/array-items dispatch.
            # Values are applied directly to the schema. If the entity field is a
            # nullable oneOf type, values will be applied to the wrapper schema,
            # not the individual variants. This is consistent with original behavior.
            if normalized.is_a?(Array) && !normalized.empty?
              schema.enum = normalized
            elsif normalized.is_a?(Range)
              RangeUtils.apply_to_schema(schema, normalized)
            end
          end
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
