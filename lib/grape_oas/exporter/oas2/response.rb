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
              "schema" => build_response_schema(resp)
              # TODO: Add headers
            }.compact
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
      end
    end
  end
end
