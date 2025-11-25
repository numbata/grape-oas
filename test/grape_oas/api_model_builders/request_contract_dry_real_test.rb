# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestContractDryRealTest < Minitest::Test
      DummyRoute = Struct.new(:options, :path, :settings)

      Contract = Dry::Schema.Params do
        required(:id).filled(:integer)
        optional(:status).maybe(:string, included_in?: %w[draft published])
        optional(:tags).array(:string, min_size?: 1, max_size?: 3)
      end

      def test_builds_schema_from_dry_contract
        route = DummyRoute.new({ contract: Contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: ApiModel::API.new(title: "t", version: "v"), route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        status = schema.properties["status"]

        assert_equal %w[draft published], status.enum
        assert status.nullable

        tags = schema.properties["tags"]

        assert_equal "array", tags.type
        assert_equal "string", tags.items.type
        assert_equal 1, tags.min_items
        assert_equal 3, tags.max_items
      end
    end
  end
end
