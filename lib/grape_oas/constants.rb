# frozen_string_literal: true

module GrapeOAS
  # Central location for constants used throughout the gem
  module Constants
    # OpenAPI/JSON Schema type strings
    module SchemaTypes
      STRING = "string"
      INTEGER = "integer"
      NUMBER = "number"
      BOOLEAN = "boolean"
      OBJECT = "object"
      ARRAY = "array"
      FILE = "file"

      ALL = [STRING, INTEGER, NUMBER, BOOLEAN, OBJECT, ARRAY, FILE].freeze
    end

    # Common MIME types
    module MimeTypes
      JSON = "application/json"
      XML = "application/xml"
      FORM_URLENCODED = "application/x-www-form-urlencoded"
      MULTIPART_FORM = "multipart/form-data"

      ALL = [JSON, XML, FORM_URLENCODED, MULTIPART_FORM].freeze
    end

    # Ruby class to schema type mapping.
    # Used for automatic type inference from parameter declarations.
    # Note: String is not included as it's the default fallback.
    RUBY_TYPE_MAPPING = {
      Integer => SchemaTypes::INTEGER,
      Float => SchemaTypes::NUMBER,
      BigDecimal => SchemaTypes::NUMBER,
      TrueClass => SchemaTypes::BOOLEAN,
      FalseClass => SchemaTypes::BOOLEAN,
      Array => SchemaTypes::ARRAY,
      Hash => SchemaTypes::OBJECT
    }.freeze

    # String type name to schema type mapping (lowercase).
    # Supports lookup with any case via primitive_type helper.
    # Note: float and bigdecimal both map to NUMBER as they represent
    # the same OpenAPI numeric type.
    PRIMITIVE_TYPE_MAPPING = {
      "float" => SchemaTypes::NUMBER,
      "bigdecimal" => SchemaTypes::NUMBER,
      "string" => SchemaTypes::STRING,
      "integer" => SchemaTypes::INTEGER,
      "boolean" => SchemaTypes::BOOLEAN,
      "grape::api::boolean" => SchemaTypes::BOOLEAN,
      "trueclass" => SchemaTypes::BOOLEAN,
      "falseclass" => SchemaTypes::BOOLEAN,
      "array" => SchemaTypes::ARRAY,
      "hash" => SchemaTypes::OBJECT
    }.freeze

    # Resolves a primitive type name to its OpenAPI schema type.
    # Normalizes the key to lowercase for consistent lookup.
    #
    # @param key [String, Symbol] The type name to resolve
    # @return [String, nil] The OpenAPI schema type or nil if not found
    def self.primitive_type(key)
      PRIMITIVE_TYPE_MAPPING[key.to_s.downcase]
    end
  end
end
