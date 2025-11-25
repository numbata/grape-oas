# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestContractDryTest < Minitest::Test
      DummyRoute = Struct.new(:options, :path, :settings)

      def api
        @api ||= ApiModel::API.new(title: "t", version: "v")
      end

      def test_optional_enum_and_array_constraints
        contract = Dry::Schema.Params do
          required(:id).filled(:integer)
          optional(:status).maybe(:string, included_in?: %w[draft published])
          optional(:tags).array(:string, min_size?: 1, max_size?: 3)
        end

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})

        Request.new(api: api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type

        status = schema.properties["status"]

        assert status.nullable
        assert_equal %w[draft published], status.enum

        tags = schema.properties["tags"]

        assert_equal 1, tags.min_items
        assert_equal 3, tags.max_items

        assert_includes schema.required, "id"
        refute_includes schema.required, "status"
      end
    end
  end
end
