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

    # HTTP method-related constants
    module HttpMethods
      # HTTP methods that typically don't have request bodies.
      # Per RFC 7231, GET/HEAD/DELETE semantics don't define body behavior,
      # but many implementations ignore them. These are treated specially
      # when generating OpenAPI specs.
      BODYLESS_HTTP_METHODS = %w[get head delete].freeze
    end

    # Common MIME types
    module MimeTypes
      JSON = "application/json"
      XML = "application/xml"
      FORM_URLENCODED = "application/x-www-form-urlencoded"
      MULTIPART_FORM = "multipart/form-data"

      ALL = [JSON, XML, FORM_URLENCODED, MULTIPART_FORM].freeze
    end

    # Default values for OpenAPI spec when not provided by user
    module Defaults
      LICENSE_NAME = "Proprietary"
      LICENSE_URL = "https://example.com/license"
      LICENSE_IDENTIFIER = "UNLICENSED"
      SERVER_URL = "https://api.example.com"
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
      Hash => SchemaTypes::OBJECT,
      File => SchemaTypes::FILE
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
      "number" => SchemaTypes::NUMBER,
      "boolean" => SchemaTypes::BOOLEAN,
      "grape::api::boolean" => SchemaTypes::BOOLEAN,
      "trueclass" => SchemaTypes::BOOLEAN,
      "falseclass" => SchemaTypes::BOOLEAN,
      "array" => SchemaTypes::ARRAY,
      "hash" => SchemaTypes::OBJECT,
      "object" => SchemaTypes::OBJECT,
      "file" => SchemaTypes::FILE,
      "rack::multipart::uploadedfile" => SchemaTypes::FILE
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
