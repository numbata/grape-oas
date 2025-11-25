# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      class Response
        def initialize(responses, ref_tracker = nil)
          @responses = responses
          @ref_tracker = ref_tracker
        end

        def build
          res = {}
          Array(@responses).each do |resp|
            res[resp.http_status] = {
              "description" => resp.description,
              "schema" => build_response_schema(resp),
              "headers" => build_headers(resp.headers),
              "examples" => build_examples(resp.media_types)
            }.compact
            res[resp.http_status].merge!(resp.extensions) if resp.extensions
            res[resp.http_status]["examples"] = resp.examples if resp.examples
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
            Schema.new(schema, @ref_tracker).build
          end
        end

        def build_headers(headers)
          return nil unless headers && !headers.empty?

          headers.each_with_object({}) do |hdr, h|
            name = hdr[:name] || hdr["name"] || hdr[:key] || hdr["key"]
            next unless name

            header_schema = hdr[:schema] || hdr["schema"] || { "type" => "string" }
            if header_schema.is_a?(Hash) && header_schema.key?("schema")
              h[name] = header_schema
            else
              h[name] = { "type" => header_schema["type"] || header_schema[:type] || header_schema }
              desc = header_schema[:description] || header_schema["description"] if header_schema.is_a?(Hash)
              h[name]["description"] = desc if desc
            end
          end
        end

        def build_examples(media_types)
          return nil unless media_types

          mt = Array(media_types).first
          return nil unless mt&.examples

          mt.examples.is_a?(Hash) ? mt.examples : { mt.mime_type => mt.examples }
        end
      end
    end
  end
end
