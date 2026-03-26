# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Handles discriminator fields in entity inheritance for polymorphic schemas.
      class DiscriminatorHandler
        # Finds the parent entity class if one exists.
        #
        # @param entity_class [Class] the entity class
        # @return [Class, nil] the parent entity class or nil
        def self.find_parent_entity(entity_class)
          EntityIntrospectorSupport.find_parent_entity(entity_class)
        end

        def initialize(entity_class)
          @entity_class = entity_class
        end

        # Applies discriminator field to the schema if one is defined.
        #
        # @param schema [ApiModel::Schema] the schema to modify
        def apply(schema)
          discriminator_field = find_discriminator_field
          schema.discriminator = discriminator_field if discriminator_field
        end

        # Checks if this entity has a discriminator field.
        #
        # @return [Boolean] true if discriminator field exists
        def discriminator?
          exposures.any? do |exposure|
            doc = exposure.documentation || {}
            doc[:is_discriminator] || doc["is_discriminator"]
          end
        rescue NoMethodError
          false
        end

        # Finds the discriminator field name from entity exposures.
        #
        # @return [String, nil] the discriminator field name or nil
        def find_discriminator_field
          exposures.each do |exposure|
            doc = exposure.documentation || {}
            is_discriminator = doc[:is_discriminator] || doc["is_discriminator"]
            return exposure.key.to_s if is_discriminator
          end
          nil
        end

        private

        def exposures
          EntityIntrospectorSupport.exposures(@entity_class)
        end
      end
    end
  end
end
