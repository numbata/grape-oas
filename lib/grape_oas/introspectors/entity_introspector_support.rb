# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    # Shared helpers used by multiple classes within EntityIntrospectorSupport.
    # These are module-level methods to avoid copy-pasting the same logic across
    # ExposureProcessor, DiscriminatorHandler, and InheritanceBuilder.
    module EntityIntrospectorSupport
      # Returns the raw exposure list for an entity class.
      # Reads root_exposures via internal Grape::Entity ivars, which is
      # unavoidable given Grape does not expose a stable public API for this.
      def self.exposures(entity_class)
        return [] unless entity_class.respond_to?(:root_exposures)

        root = entity_class.root_exposures
        list = root.instance_variable_get(:@exposures) || []
        Array(list)
      rescue NoMethodError
        []
      end

      # Resolves the canonical name for an entity class, preferring entity_name
      # when defined directly on the class and non-blank, falling back to the
      # Ruby class name. Inherited entity_name is ignored to avoid collisions
      # between parent and child schemas.
      def self.resolve_canonical_name(entity_class)
        if entity_class.respond_to?(:entity_name) &&
           entity_class.method(:entity_name).owner == entity_class.singleton_class
          name = entity_class.entity_name
          name.is_a?(String) && !name.strip.empty? ? name : entity_class.name
        else
          entity_class.name
        end
      end

      # Finds the parent entity class if one exists in the Grape::Entity hierarchy.
      def self.find_parent_entity(entity_class)
        return nil unless defined?(Grape::Entity)

        parent = entity_class.superclass
        return nil unless parent && parent < Grape::Entity && parent != Grape::Entity

        parent
      end
    end
  end
end
