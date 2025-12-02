# frozen_string_literal: true

require "bigdecimal"

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Centralizes Ruby type to OpenAPI schema type resolution.
      # Used by request builders and introspectors to avoid duplicated type switching logic.
      module TypeResolver
        # Resolves a Ruby class or type name to its OpenAPI schema type string.
        # Handles both Ruby classes (Integer, Float) and string type names ("integer", "float").
        # Falls back to "string" for unknown types.
        #
        # @param type [Class, String, Symbol, nil] The type to resolve
        # @return [String] The OpenAPI schema type
        def resolve_schema_type(type)
          return Constants::SchemaTypes::STRING if type.nil?

          # Handle Ruby classes directly
          return Constants::RUBY_TYPE_MAPPING.fetch(type, Constants::SchemaTypes::STRING) if type.is_a?(Class)

          # Handle string/symbol type names
          type_str = type.to_s.downcase
          Constants::PRIMITIVE_TYPE_MAPPING.fetch(type_str, Constants::SchemaTypes::STRING)
        end

        # Builds a basic Schema object for the given Ruby primitive type.
        # Handles special cases like Array and Hash.
        #
        # @param primitive [Class, nil] The Ruby primitive class
        # @param member [Object, nil] For arrays, the member type
        # @return [ApiModel::Schema] The schema object
        def build_schema_for_primitive(primitive, member: nil)
          case primitive
          when Array
            items_schema = member ? build_schema_for_primitive(derive_primitive(member)) : default_string_schema
            ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
          when Hash
            ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          else
            ApiModel::Schema.new(type: resolve_schema_type(primitive))
          end
        end

        private

        def default_string_schema
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        end

        def derive_primitive(type)
          type.respond_to?(:primitive) ? type.primitive : type
        end
      end
    end
  end
end
