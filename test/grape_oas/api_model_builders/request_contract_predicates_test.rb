# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestContractPredicatesTest < Minitest::Test
      DummyRoute = Struct.new(:options, :path, :settings)

      def api
        @api ||= ApiModel::API.new(title: "t", version: "v")
      end

      def test_string_size_and_format_and_enum
        contract = Dry::Schema.Params do
          optional(:status).maybe(:string, min_size?: 5, max_size?: 50, format?: /\A[a-z]+\z/,
                                           included_in?: %w[draft published],)
        end

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})

        Request.new(api: api, route: route, operation: operation).build

        status = operation.request_body.media_types.first.schema.properties["status"]

        assert_equal 5, status.min_length
        assert_equal 50, status.max_length
        assert_equal "\\A[a-z]+\\z", status.pattern
        assert_equal %w[draft published], status.enum
        assert status.nullable
        refute_includes operation.request_body.media_types.first.schema.required, "status"
      end

      def test_numeric_bounds_and_excluded
        contract = Dry::Schema.Params do
          required(:score).filled(:integer, gteq?: 1, lteq?: 10, excluded_from?: [5])
        end

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})

        Request.new(api: api, route: route, operation: operation).build

        score = operation.request_body.media_types.first.schema.properties["score"]

        assert_equal 1, score.minimum
        assert_equal 10, score.maximum
        assert_equal [5], score.extensions["x-excludedValues"]
        assert_includes operation.request_body.media_types.first.schema.required, "score"
      end

      def test_array_with_item_constraints_and_nullable
        contract = Dry::Schema.Params do
          optional(:tags).array(:string, min_size?: 1, max_size?: 3)
        end

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})

        Request.new(api: api, route: route, operation: operation).build

        tags = operation.request_body.media_types.first.schema.properties["tags"]

        assert_equal "array", tags.type
        assert_equal "string", tags.items.type
        assert_equal 1, tags.min_items
        assert_equal 3, tags.max_items
        refute tags.nullable
        refute_includes operation.request_body.media_types.first.schema.required, "tags"
      end
    end
  end
end
