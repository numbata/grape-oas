# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Response
        def initialize(responses, ref_tracker = nil, nullable_keyword: true)
          @responses = responses
          @ref_tracker = ref_tracker
          @nullable_keyword = nullable_keyword
        end

        def build
          @responses.each_with_object({}) do |resp, h|
            h[resp.http_status] = {
              "description" => resp.description || "Response",
              "headers" => build_headers(resp.headers),
              "content" => build_content(resp.media_types)
            }.compact
            h[resp.http_status].merge!(resp.extensions) if resp.extensions
            h[resp.http_status]["examples"] = normalize_examples(resp.examples) if resp.examples
          end
        end

        private

        def build_headers(headers)
          return nil unless headers && !headers.empty?

          headers.each_with_object({}) do |hdr, h|
            name = hdr[:name] || hdr["name"] || hdr[:key] || hdr["key"]
            next unless name

            h[name] = (hdr[:schema] || hdr["schema"] || { "schema" => { "type" => "string" } })
          end
        end

        def build_content(media_types)
          return nil unless media_types

          media_types.each_with_object({}) do |mt, h|
            entry = {
              "schema" => build_schema_or_ref(mt.schema),
              "examples" => normalize_examples(mt.examples)
            }
            entry["example"] = mt.examples if mt.examples && !mt.examples.is_a?(Hash)
            h[mt.mime_type] = entry.compact
          end
        end

        def normalize_examples(examples)
          return nil unless examples
          return examples if examples.is_a?(Hash)

          { "default" => examples }
        end

        def build_schema_or_ref(schema)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            { "$ref" => "#/components/schemas/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker, nullable_keyword: @nullable_keyword).build
          end
        end
      end
    end
  end
end
