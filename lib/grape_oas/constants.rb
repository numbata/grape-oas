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
    end

    # Ruby class to schema type mapping
    RUBY_TYPE_MAPPING = {
      Integer => SchemaTypes::INTEGER,
      Float => SchemaTypes::NUMBER,
      BigDecimal => SchemaTypes::NUMBER,
      TrueClass => SchemaTypes::BOOLEAN,
      FalseClass => SchemaTypes::BOOLEAN,
      Array => SchemaTypes::ARRAY,
      Hash => SchemaTypes::OBJECT
    }.freeze

    # String type name to schema type mapping (lowercase)
    PRIMITIVE_TYPE_MAPPING = {
      "float" => SchemaTypes::NUMBER,
      "bigdecimal" => SchemaTypes::NUMBER,
      "string" => SchemaTypes::STRING,
      "integer" => SchemaTypes::INTEGER,
      "boolean" => SchemaTypes::BOOLEAN,
      "grape::api::boolean" => SchemaTypes::BOOLEAN,
      "trueclass" => SchemaTypes::BOOLEAN,
      "falseclass" => SchemaTypes::BOOLEAN
    }.freeze
  end
end
