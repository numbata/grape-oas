# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class RequestBody
        def initialize(request_body, ref_tracker = nil, nullable_keyword: true)
          @request_body = request_body
          @ref_tracker = ref_tracker
          @nullable_keyword = nullable_keyword
        end

        def build
          return nil unless @request_body

          data = {
            "description" => @request_body.description,
            "required" => @request_body.required,
            "content" => build_content(@request_body.media_types)
          }.compact

          data.merge!(@request_body.extensions) if @request_body.extensions&.any?
          data
        end

        private

        def build_content(media_types)
          return nil unless media_types

          media_types.each_with_object({}) do |mt, h|
            entry = {
              "schema" => Schema.new(mt.schema, @ref_tracker, nullable_keyword: @nullable_keyword).build,
              "examples" => mt.examples
            }.compact
            entry.merge!(mt.extensions) if mt.extensions&.any?
            h[mt.mime_type] = entry
          end
        end
      end
    end
  end
end
