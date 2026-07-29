# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module Base
      # Helpers for the `array_use_braces` option, which appends `[]` to the
      # names of array parameters so clients that expect Rails/PHP-style array
      # field names (e.g. `ids[]`) get them. Applied only to query-string
      # parameters and form/multipart body properties — never to JSON bodies,
      # path params, or header params.
      module ArrayBraces
        FORM_MIME_TYPES = [
          Constants::MimeTypes::FORM_URLENCODED,
          Constants::MimeTypes::MULTIPART_FORM
        ].freeze

        module_function

        # Display name for a query-string parameter, with `[]` appended when the
        # option is enabled and the parameter is an array.
        def param_name(param, enabled:)
          return param.name unless enabled
          return param.name unless param.location == "query"
          return param.name unless array_schema?(param.schema)

          "#{param.name}[]"
        end

        def form_encoded?(mime_type)
          FORM_MIME_TYPES.include?(mime_type)
        end

        # Rename top-level array property keys (and their `required` entries) on
        # an already-emitted schema Hash to use the `[]` suffix. Mutates and
        # returns the Hash. No-ops on `$ref` entries (no inline properties).
        def apply_to_schema(schema_hash)
          props = schema_hash["properties"]
          return schema_hash unless props.is_a?(Hash)

          rename_map = {}
          renamed = props.each_with_object({}) do |(key, value), acc|
            new_key = array_type?(value["type"]) ? "#{key}[]" : key
            rename_map[key] = new_key
            acc[new_key] = value
          end
          schema_hash["properties"] = renamed

          required = schema_hash["required"]
          schema_hash["required"] = required.map { |name| rename_map[name] || name } if required.is_a?(Array)

          schema_hash
        end

        def array_schema?(schema)
          schema.respond_to?(:type) && schema.type == Constants::SchemaTypes::ARRAY
        end

        def array_type?(type)
          type == Constants::SchemaTypes::ARRAY ||
            (type.is_a?(Array) && type.include?(Constants::SchemaTypes::ARRAY))
        end
      end
    end
  end
end
