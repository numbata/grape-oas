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

    # Nullable representation strategies for different OpenAPI versions.
    # Passed via `nullable_strategy:` option to control how nullable fields
    # are represented in the generated schema.
    module NullableStrategy
      # OAS 3.0: emits `"nullable": true` alongside the type
      KEYWORD = :keyword
      # OAS 3.1: emits `"type": ["string", "null"]` (JSON Schema style)
      TYPE_ARRAY = :type_array
      # OAS 2.0: emits `"x-nullable": true` extension
      EXTENSION = :extension
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
      TrueClass => SchemaTypes::BOOLEAN,
      FalseClass => SchemaTypes::BOOLEAN,
      Array => SchemaTypes::ARRAY,
      Hash => SchemaTypes::OBJECT,
      File => SchemaTypes::FILE
    }.tap do |mapping|
      mapping.default_proc = lambda do |_hash, key|
        key.is_a?(Class) && key.to_s == "BigDecimal" ? SchemaTypes::NUMBER : nil
      end
    end.freeze

    # String type name to schema type and format mapping (lowercase).
    # Supports lookup with any case via primitive_type helper.
    # Each entry contains :type and optional :format for OpenAPI schema generation.
    #
    # @see https://swagger.io/specification/#data-types
    # @see https://spec.openapis.org/registry/format/
    PRIMITIVE_TYPE_MAPPING = {
      "float" => { type: SchemaTypes::NUMBER, format: "float" },
      "bigdecimal" => { type: SchemaTypes::NUMBER, format: "double" },
      "string" => { type: SchemaTypes::STRING },
      "integer" => { type: SchemaTypes::INTEGER, format: "int32" },
      "number" => { type: SchemaTypes::NUMBER, format: "double" },
      "boolean" => { type: SchemaTypes::BOOLEAN },
      "grape::api::boolean" => { type: SchemaTypes::BOOLEAN },
      "trueclass" => { type: SchemaTypes::BOOLEAN },
      "falseclass" => { type: SchemaTypes::BOOLEAN },
      "array" => { type: SchemaTypes::ARRAY },
      "hash" => { type: SchemaTypes::OBJECT },
      "object" => { type: SchemaTypes::OBJECT },
      "file" => { type: SchemaTypes::FILE },
      "rack::multipart::uploadedfile" => { type: SchemaTypes::FILE }
    }.freeze

    # Resolves a primitive type name to its OpenAPI schema type.
    # Normalizes the key to lowercase for consistent lookup.
    #
    # @param key [String, Symbol, Class] The type name to resolve
    # @return [String, nil] The OpenAPI schema type or nil if not found
    def self.primitive_type(key)
      entry = PRIMITIVE_TYPE_MAPPING[key.to_s.downcase]
      entry&.fetch(:type, nil)
    end

    # Resolves the default format for a given type.
    # Returns nil if no specific format applies (e.g., for strings, booleans).
    #
    # @param key [String, Symbol, Class] The type name to resolve format for
    # @return [String, nil] The OpenAPI format or nil if not applicable
    def self.format_for_type(key)
      entry = PRIMITIVE_TYPE_MAPPING[key.to_s.downcase]
      entry&.fetch(:format, nil)
    end
  end
end
