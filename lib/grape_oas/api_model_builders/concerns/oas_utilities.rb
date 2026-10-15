# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Shared utility methods for OpenAPI schema building.
      module OasUtilities
        # Regex pattern for valid Ruby constant names (used for entity resolution)
        VALID_CONSTANT_PATTERN = /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*\z/

        # Extracts OpenAPI extension fields (x-* prefixed keys) from a hash.
        #
        # @param hash [Hash] the source hash
        # @return [Hash, nil] hash of extension fields, or nil if empty
        def self.extract_extensions(hash)
          return nil unless hash.is_a?(Hash)

          ext = hash.select { |k, _| k.to_s.start_with?("x-") }
          ext.empty? ? nil : ext
        end

        # Instance method version for including in classes
        def extract_extensions(hash)
          OasUtilities.extract_extensions(hash)
        end

        # Extracts nullable flag from a documentation hash.
        #
        # @param doc [Hash] the documentation hash
        # @return [Boolean] true if nullable
        def self.extract_nullable(doc)
          doc[:nullable] || (doc[:x].is_a?(Hash) && doc[:x][:nullable]) || false
        end

        # Instance method version
        def extract_nullable(doc)
          OasUtilities.extract_nullable(doc)
        end

        # Marks a schema as deprecated when the documentation hash asks for it.
        # A schema with a canonical name is a shared component, so the flag
        # goes on an allOf wrapper and the component stays unchanged.
        #
        # @param schema [ApiModel::Schema] the schema to mark
        # @param doc [Hash] the documentation hash
        # @return [ApiModel::Schema] the schema, or its wrapper
        def self.apply_deprecated(schema, doc)
          return schema unless doc[:deprecated]

          schema = ApiModel::Schema.new(all_of: [schema]) if schema.canonical_name
          schema.deprecated = true
          schema
        end

        # Instance method version
        def apply_deprecated(schema, doc)
          OasUtilities.apply_deprecated(schema, doc)
        end

        # Converts a CamelCase string to snake_case.
        #
        # @param str [String] the string to convert
        # @return [String] the underscored string
        def self.underscore(str)
          str.gsub("::", "/")
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
             .tr("-", "_")
             .downcase
        end

        # Instance method version
        def underscore(str)
          OasUtilities.underscore(str)
        end

        # Simple pluralization (basic English rules).
        #
        # @param key [String] the string to pluralize
        # @return [String] the pluralized string
        def self.pluralize(key)
          return "#{key}es" if key.end_with?("s", "x", "z", "ch", "sh")
          return "#{key[0..-2]}ies" if key.end_with?("y") && !%w[a e i o u].include?(key[-2])

          "#{key}s"
        end

        # Instance method version
        def pluralize(key)
          OasUtilities.pluralize(key)
        end

        # Checks if a string matches the valid Ruby constant pattern.
        #
        # @param str [String] the string to check
        # @return [Boolean] true if valid constant name
        def self.valid_constant_name?(str)
          str.is_a?(String) && str.match?(VALID_CONSTANT_PATTERN)
        end

        # Instance method version
        def valid_constant_name?(str)
          OasUtilities.valid_constant_name?(str)
        end
      end
    end
  end
end
