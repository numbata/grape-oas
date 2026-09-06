# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class RequestBody
        def initialize(request_body, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD,
                       schema_builder: Schema)
          @request_body = request_body
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
          @schema_builder = schema_builder
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
            schema_entry = build_schema_or_ref(mt.schema)
            entry = {
              "schema" => schema_entry,
              "examples" => mt.examples
            }.compact
            entry.merge!(mt.extensions) if mt.extensions&.any?
            h[mt.mime_type] = entry
          end
        end

        def build_schema_or_ref(schema)
          @schema_builder.new(schema, @ref_tracker, nullable_strategy: @nullable_strategy)
                         .build_schema_or_ref(schema)
        end
      end
    end
  end
end
