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
      #
      # @param entity_class [Class] a Grape::Entity subclass
      # @return [Array] list of exposures; empty on any error
      def self.exposures(entity_class)
        return [] unless entity_class.respond_to?(:root_exposures)

        root = entity_class.root_exposures
        list = root.instance_variable_get(:@exposures) || []
        Array(list)
      rescue NoMethodError
        []
      end

      # Finds the parent entity class if one exists in the Grape::Entity hierarchy.
      #
      # @param entity_class [Class] a Grape::Entity subclass
      # @return [Class, nil] the immediate Grape::Entity parent, or nil
      def self.find_parent_entity(entity_class)
        return nil unless defined?(Grape::Entity)

        parent = entity_class.superclass
        return nil unless parent && parent < Grape::Entity && parent != Grape::Entity

        parent
      end
    end
  end
end
