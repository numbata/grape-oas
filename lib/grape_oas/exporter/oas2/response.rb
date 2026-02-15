# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      class Response
        def initialize(responses, ref_tracker = nil, nullable_strategy: nil)
          @responses = responses
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
        end

        def build
          res = {}
          Array(@responses).each do |resp|
            res[resp.http_status] = {
              "description" => resp.description,
              "schema" => build_response_schema(resp),
              "headers" => build_headers(resp.headers),
              "examples" => build_examples(resp.media_types, resp.examples)
            }.compact
            res[resp.http_status].merge!(resp.extensions) if resp.extensions
          end
          res
        end

        private

        def build_response_schema(resp)
          mt = Array(resp.media_types).first
          mt ? build_schema_or_ref(mt.schema) : nil
        end

        def build_schema_or_ref(schema)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            { "$ref" => "#/definitions/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
          end
        end

        def build_headers(headers)
          return nil unless headers && !headers.empty?

          headers.each_with_object({}) do |hdr, h|
            name = hdr[:name] || hdr["name"] || hdr[:key] || hdr["key"]
            next unless name

            # OAS2 headers have type at top level (not wrapped in schema)
            schema_value = hdr[:schema] || hdr["schema"] || {}
            schema_type = schema_value["type"] || schema_value[:type] || Constants::SchemaTypes::STRING
            description = hdr[:description] || hdr["description"] || schema_value["description"]

            header_obj = { "type" => schema_type }
            header_obj["description"] = description if description
            h[name] = header_obj
          end
        end

        def build_examples(media_types, response_examples = nil)
          return nil unless media_types

          mt = Array(media_types).first
          # Media type examples take precedence over response-level examples
          examples = mt&.examples || response_examples
          return nil unless examples

          examples.is_a?(Hash) ? examples : { mt&.mime_type || "application/json" => examples }
        end
      end
    end
  end
end
