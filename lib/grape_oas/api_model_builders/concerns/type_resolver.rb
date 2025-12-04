# frozen_string_literal: true

require "bigdecimal"

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Centralizes Ruby type to OpenAPI schema type resolution.
      # Used by request builders and introspectors to avoid duplicated type switching logic.
      module TypeResolver
        # Regex to match Grape's typed array notation like "[String]", "[Integer]"
        TYPED_ARRAY_PATTERN = /^\[(\w+)\]$/

        # Regex to match Grape's multi-type notation like "[String, Integer]", "[String, Float]"
        MULTI_TYPE_PATTERN = /^\[(\w+(?:::\w+)*(?:,\s*\w+(?:::\w+)*)+)\]$/

        # Resolves a Ruby class or type name to its OpenAPI schema type string.
        # Handles both Ruby classes (Integer, Float) and string type names ("integer", "float").
        # Also handles Grape's "[Type]" notation for typed arrays.
        # Falls back to "string" for unknown types.
        #
        # @param type [Class, String, Symbol, nil] The type to resolve
        # @return [String] The OpenAPI schema type
        def resolve_schema_type(type)
          return Constants::SchemaTypes::STRING if type.nil?

          # Handle Ruby classes directly
          if type.is_a?(Class)
            # Check static mapping first
            return Constants::RUBY_TYPE_MAPPING[type] if Constants::RUBY_TYPE_MAPPING.key?(type)

            # Handle Grape::API::Boolean dynamically (may not be loaded at constant definition time)
            return Constants::SchemaTypes::BOOLEAN if grape_boolean_type?(type)

            return Constants::SchemaTypes::STRING
          end

          type_str = type.to_s

          # Handle Grape's typed array notation like "[String]"
          return Constants::SchemaTypes::ARRAY if type_str.match?(TYPED_ARRAY_PATTERN)

          # Handle string/symbol type names
          Constants::PRIMITIVE_TYPE_MAPPING.fetch(type_str.downcase, Constants::SchemaTypes::STRING)
        end

        # Checks if type is Grape's Boolean class (handles dynamic loading)
        def grape_boolean_type?(type)
          return false unless defined?(Grape::API::Boolean)

          type == Grape::API::Boolean || type.to_s == "Grape::API::Boolean"
        end

        # Extracts the member type from Grape's "[Type]" notation.
        # Returns nil if not a typed array.
        #
        # @param type [String] The type string to parse
        # @return [String, nil] The inner type or nil
        def extract_typed_array_member(type)
          return nil unless type.is_a?(String)

          match = type.match(TYPED_ARRAY_PATTERN)
          match ? match[1] : nil
        end

        # Checks if type is a multi-type notation like "[String, Integer]"
        #
        # @param type [String] The type string to check
        # @return [Boolean] true if multi-type notation
        def multi_type?(type)
          return false unless type.is_a?(String)

          type.match?(MULTI_TYPE_PATTERN)
        end

        # Extracts individual types from Grape's multi-type notation "[String, Integer]"
        # Returns nil if not a multi-type notation.
        #
        # @param type [String] The type string to parse
        # @return [Array<String>, nil] Array of type names or nil
        def extract_multi_types(type)
          return nil unless type.is_a?(String)

          match = type.match(MULTI_TYPE_PATTERN)
          return nil unless match

          match[1].split(/,\s*/)
        end

        # Builds a basic Schema object for the given Ruby primitive type.
        # Handles special cases like Array and Hash.
        # Note: Uses == instead of case/when because Ruby's === doesn't work for class equality
        # (Array === Array returns false since Array is not an instance of Array)
        #
        # @param primitive [Class, nil] The Ruby primitive class
        # @param member [Object, nil] For arrays, the member type
        # @return [ApiModel::Schema] The schema object
        def build_schema_for_primitive(primitive, member: nil)
          if primitive == Array
            items_schema = build_array_items_schema(member)
            ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
          elsif primitive == Hash
            ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          else
            ApiModel::Schema.new(type: resolve_schema_type(primitive))
          end
        end

        # Builds schema for array items, handling nested arrays recursively.
        #
        # @param member [Object, nil] The member type
        # @return [ApiModel::Schema] The items schema
        def build_array_items_schema(member)
          return default_string_schema unless member

          member_primitive, member_member = derive_primitive_and_member(member)
          build_schema_for_primitive(member_primitive, member: member_member)
        end

        # Derives primitive type and nested member from a type.
        # For Dry::Types, extracts the primitive and member type.
        # For plain Ruby classes, returns the class with nil member.
        #
        # @param type [Object] The type to analyze
        # @return [Array<Class, Object>] [primitive, member] tuple
        def derive_primitive_and_member(type)
          return [type, nil] unless type.respond_to?(:primitive)

          primitive = type.primitive
          member = type.respond_to?(:member) ? type.member : nil
          [primitive, member]
        end

        private

        def default_string_schema
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        end
      end
    end
  end
end
