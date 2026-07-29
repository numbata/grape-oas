# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class RequestBody
        def initialize(request_body, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD,
                       array_use_braces: false)
          @request_body = request_body
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
          @array_use_braces = array_use_braces
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
            schema_entry = build_schema_entry(mt)
            entry = {
              "schema" => schema_entry,
              "examples" => mt.examples
            }.compact
            entry.merge!(mt.extensions) if mt.extensions&.any?
            h[mt.mime_type] = entry
          end
        end

        # When array_use_braces is on and this media type is form/multipart encoded, inline the
        # schema (instead of emitting a shared $ref) so we can append `[]` to its array property
        # names without affecting the JSON media type or the shared component schema.
        def build_schema_entry(media_type)
          if @array_use_braces && Base::ArrayBraces.form_encoded?(media_type.mime_type)
            inline = Schema.new(media_type.schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
            return Base::ArrayBraces.apply_to_schema(inline)
          end

          build_schema_or_ref(media_type.schema)
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
