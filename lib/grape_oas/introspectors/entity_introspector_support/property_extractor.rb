# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Utility class for extracting properties from entity documentation hashes.
      # All methods are stateless and can be called directly on the class.
      class PropertyExtractor
        class << self
          # Extracts description from a documentation hash.
          #
          # @param hash [Hash] the documentation hash
          # @return [String, nil] the description value
          def extract_description(hash)
            desc = hash[:description] || hash[:desc]
            desc.is_a?(String) ? desc : nil
          end

          # Extracts nullable flag from a documentation hash.
          #
          # @param doc [Hash] the documentation hash
          # @return [Boolean] true if nullable
          def extract_nullable(doc)
            doc[:nullable] || doc["nullable"] || false
          end

          # Extracts merge flag from exposure options and documentation.
          #
          # @param exposure the entity exposure
          # @param doc [Hash] the documentation hash
          # @param opts [Hash] the options hash
          # @return [Boolean, nil] true if this is a merge exposure
          def extract_merge_flag(exposure, doc, opts)
            opts[:merge] || doc[:merge] || (exposure.respond_to?(:for_merge) && exposure.for_merge)
          end

          # Applies entity-level properties to a schema.
          #
          # @param schema [ApiModel::Schema] the schema to modify
          # @param doc [Hash] the entity documentation hash
          def apply_entity_level_properties(schema, doc)
            schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
            schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)

            defs = doc[:defs] || doc[:$defs]
            schema.defs = defs if defs.is_a?(Hash)
          rescue NoMethodError
            # Silently handle errors when schema doesn't respond to setters
          end
        end
      end
    end
  end
end
