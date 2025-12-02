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
          return Constants::RUBY_TYPE_MAPPING.fetch(type, Constants::SchemaTypes::STRING) if type.is_a?(Class)

          type_str = type.to_s

          # Handle Grape's typed array notation like "[String]"
          return Constants::SchemaTypes::ARRAY if type_str.match?(TYPED_ARRAY_PATTERN)

          # Handle string/symbol type names
          Constants::PRIMITIVE_TYPE_MAPPING.fetch(type_str.downcase, Constants::SchemaTypes::STRING)
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
