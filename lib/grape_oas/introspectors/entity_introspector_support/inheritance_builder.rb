# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Handles entity inheritance and builds allOf schemas for parent-child entity relationships.
      class InheritanceBuilder
        def initialize(entity_class, stack:, registry:)
          @entity_class = entity_class
          @stack = stack
          @registry = registry
        end

        # Finds the parent entity class if one exists.
        #
        # @param entity_class [Class] the entity class to check
        # @return [Class, nil] the parent entity class or nil
        def self.find_parent_entity(entity_class)
          return nil unless defined?(Grape::Entity)

          parent = entity_class.superclass
          return nil unless parent && parent < Grape::Entity && parent != Grape::Entity

          parent
        end

        # Checks if an entity inherits from a parent that uses discriminator.
        #
        # @param entity_class [Class] the entity class to check
        # @return [Boolean] true if parent has a discriminator field
        def self.inherits_with_discriminator?(entity_class)
          parent = find_parent_entity(entity_class)
          parent && DiscriminatorHandler.new(parent).discriminator?
        end

        # Builds an inherited schema using allOf composition.
        #
        # @param parent_entity [Class] the parent entity class
        # @return [ApiModel::Schema] the composed schema
        def build_inherited_schema(parent_entity)
          # First, ensure parent schema is built
          parent_schema = GrapeOAS.introspectors.build_schema(parent_entity, stack: @stack, registry: @registry)

          # Build child-specific properties (excluding inherited ones)
          child_schema = build_child_only_schema(parent_entity)

          # Create allOf schema with ref to parent + child properties
          schema = ApiModel::Schema.new(
            canonical_name: @entity_class.name,
            all_of: [parent_schema, child_schema],
          )

          @registry[@entity_class] = schema
          schema
        end

        private

        def build_child_only_schema(parent_entity)
          child_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          processor = ExposureProcessor.new(@entity_class, stack: @stack, registry: @registry)

          # Get parent's exposure keys to exclude
          parent_keys = processor.parent_exposures(parent_entity).map { |e| e.key.to_s }

          processor.exposures.each do |exposure|
            next unless processor.exposed?(exposure)

            name = exposure.key.to_s
            # Skip if this is an inherited property
            next if parent_keys.include?(name)

            add_child_property(child_schema, exposure, processor)
          end

          child_schema
        end

        def add_child_property(child_schema, exposure, processor)
          doc = exposure.documentation || {}
          opts = exposure.instance_variable_get(:@options) || {}

          return if processor.merge_exposure?(exposure, doc, opts)

          prop_schema = processor.schema_for_exposure(exposure, doc)
          doc = apply_conditional_modifiers(prop_schema, doc, exposure, processor)
          prop_schema = wrap_in_array_if_needed(prop_schema, doc)

          child_schema.add_property(exposure.key.to_s, prop_schema, required: doc[:required])
        end

        def apply_conditional_modifiers(_prop_schema, doc, exposure, processor)
          return doc unless processor.conditional?(exposure)

          # Conditional exposures are not required (may be absent from output),
          # but they are NOT nullable - when present, the value is not null.
          doc.merge(required: false)
        end

        def wrap_in_array_if_needed(prop_schema, doc)
          is_array = doc[:is_array] || doc["is_array"]
          return prop_schema unless is_array

          ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: prop_schema)
        end
      end
    end
  end
end
