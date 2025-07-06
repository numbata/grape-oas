# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Response
      attr_reader :api, :route

      def initialize(api:, route:)
        @api = api
        @route = route
      end

      def build
        result_schema = build_schema

        media_type = build_media_type(
          mime_type: "application/json",
          schema: result_schema,
        )

        GrapeOAS::ApiModel::Response.new(
          http_status: "200",
          description: "Success",
          media_types: [media_type],
        )
      end

      private

      def build_schema
        entity_class = route.options[:entity]

        schema_args = if entity_class
                        { type: "object", canonical_name: entity_class.name }
                      else
                        { type: "string" }
                      end

        GrapeOAS::ApiModel::Schema.new(**schema_args)
      end

      def build_media_type(mime_type:, schema:)
        GrapeOAS::ApiModel::MediaType.new(
          mime_type: mime_type,
          schema: schema,
        )
      end
    end
  end
end
