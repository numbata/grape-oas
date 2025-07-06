# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Request
      attr_reader :api, :route, :operation

      def initialize(api:, route:, operation:)
        @api = api
        @route = route
        @operation = operation
      end

      def build
        body_schema, route_params = GrapeOAS::ApiModelBuilders::RequestParams
                                    .new(api: api, route: route)
                                    .build

        operation.add_parameters(*route_params)
        append_request_body(body_schema) unless body_schema.empty?
      end

      private

      def append_request_body(body_schema)
        media_type = GrapeOAS::ApiModel::MediaType.new(
          mime_type: "application/json",
          schema: body_schema,
        )
        operation.request_body = GrapeOAS::ApiModel::RequestBody.new(
          required: body_schema.any?(&:required),
          media_types: [media_type],
        )
      end
    end
  end
end
