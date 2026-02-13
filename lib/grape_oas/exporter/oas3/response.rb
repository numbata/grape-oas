# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Response
        def initialize(responses, ref_tracker = nil, nullable_strategy: true)
          @responses = responses
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
        end

        def build
          @responses.each_with_object({}) do |resp, h|
            h[resp.http_status] = {
              "description" => resp.description || "Response",
              "headers" => build_headers(resp.headers),
              "content" => build_content(resp.media_types, resp.examples)
            }.compact
            h[resp.http_status].merge!(resp.extensions) if resp.extensions
          end
        end

        private

        def build_headers(headers)
          return nil unless headers && !headers.empty?

          headers.each_with_object({}) do |hdr, h|
            name = hdr[:name] || hdr["name"] || hdr[:key] || hdr["key"]
            next unless name

            # OAS3 requires headers to have schema wrapper and optional description
            schema_value = hdr[:schema] || hdr["schema"] || {}
            schema_type = schema_value["type"] || schema_value[:type] || Constants::SchemaTypes::STRING
            description = hdr[:description] || hdr["description"] || schema_value["description"]

            header_obj = { "schema" => { "type" => schema_type } }
            header_obj["description"] = description if description
            h[name] = header_obj
          end
        end

        def build_content(media_types, response_examples = nil)
          return nil unless media_types

          media_types.each_with_object({}) do |mt, h|
            entry = { "schema" => build_schema_or_ref(mt.schema) }
            # OAS3: use "example" for single value, "examples" for named examples with value wrapper
            # Media type examples take precedence over response-level examples
            examples = mt.examples || response_examples
            add_examples_to_entry(entry, examples)
            h[mt.mime_type] = entry.compact
          end
        end

        # OAS3 examples must be wrapped as { name => { "value" => ... } }
        # Use "example" (singular) for simple cases, "examples" for multiple/named
        def add_examples_to_entry(entry, examples)
          return unless examples

          if examples.is_a?(Hash) && examples.keys.all? { |k| k.is_a?(String) || k.is_a?(Symbol) }
            # Named examples - wrap each value if not already wrapped
            entry["examples"] = examples.transform_values do |v|
              v.is_a?(Hash) && v.key?("value") ? v : { "value" => v }
            end
          else
            # Single example value
            entry["example"] = examples
          end
        end

        def build_schema_or_ref(schema)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            { "$ref" => "#/components/schemas/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
          end
        end
      end
    end
  end
end
