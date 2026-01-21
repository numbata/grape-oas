# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestContractDryTest < Minitest::Test
      def api
        @api ||= ApiModel::API.new(title: "t", version: "v")
      end

      # === Basic contract schema building ===

      def test_optional_enum_and_array_constraints
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:id).filled(:integer)
            optional(:status).maybe(:string, included_in?: %w[draft published])
            optional(:tags).value(:array, min_size?: 1, max_size?: 3).each(:string)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

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

      # === String predicate tests ===

      def test_string_size_and_format_and_enum
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            optional(:status).maybe(:string, min_size?: 5, max_size?: 50, format?: /\A[a-z]+\z/,
                                             included_in?: %w[draft published],)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: api, route: route, operation: operation).build

        status = operation.request_body.media_types.first.schema.properties["status"]

        assert_equal 5, status.min_length
        assert_equal 50, status.max_length
        assert_equal "\\A[a-z]+\\z", status.pattern
        assert_equal %w[draft published], status.enum
        assert status.nullable
        refute_includes operation.request_body.media_types.first.schema.required, "status"
      end

      # === Numeric predicate tests ===

      def test_numeric_bounds_and_excluded
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:score).filled(:integer, gteq?: 1, lteq?: 10, excluded_from?: [5])
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: api, route: route, operation: operation).build

        score = operation.request_body.media_types.first.schema.properties["score"]

        assert_equal 1, score.minimum
        assert_equal 10, score.maximum
        assert_equal [5], score.extensions["x-excludedValues"]
        assert_includes operation.request_body.media_types.first.schema.required, "score"
      end

      # === Array predicate tests ===

      def test_array_with_item_constraints_and_nullable
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            optional(:tags).value(:array, min_size?: 1, max_size?: 3).each(:string)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: api, route: route, operation: operation).build

        tags = operation.request_body.media_types.first.schema.properties["tags"]

        assert_equal "array", tags.type
        assert_equal "string", tags.items.type
        assert_equal 1, tags.min_items
        assert_equal 3, tags.max_items
        refute tags.nullable
        refute_includes operation.request_body.media_types.first.schema.required, "tags"
      end

      # === Multiple routes with different contracts ===

      def test_multiple_routes_with_different_contracts_use_correct_schemas
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:user_name).filled(:string)
            required(:email).filled(:string)
          end

          post "/users" do
            {}
          end

          contract Dry::Schema.Params do
            required(:product_id).filled(:integer)
            required(:quantity).filled(:integer)
          end

          post "/orders" do
            {}
          end

          contract Dry::Schema.Params do
            required(:title).filled(:string)
            optional(:body).maybe(:string)
          end

          post "/articles" do
            {}
          end
        end

        routes = api_class.routes

        # Find routes by path
        users_route = routes.find { |r| r.path == "/users(.json)" }
        orders_route = routes.find { |r| r.path == "/orders(.json)" }
        articles_route = routes.find { |r| r.path == "/articles(.json)" }

        # Build operations for each route
        users_op = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        Request.new(api: api, route: users_route, operation: users_op).build

        orders_op = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        Request.new(api: api, route: orders_route, operation: orders_op).build

        articles_op = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        Request.new(api: api, route: articles_route, operation: articles_op).build

        # Verify /users route has user_name and email fields
        users_schema = users_op.request_body.media_types.first.schema
        assert users_schema.properties.key?("user_name"), "users route should have user_name"
        assert users_schema.properties.key?("email"), "users route should have email"
        refute users_schema.properties.key?("product_id"), "users route should NOT have product_id"
        refute users_schema.properties.key?("title"), "users route should NOT have title"

        # Verify /orders route has product_id and quantity fields
        orders_schema = orders_op.request_body.media_types.first.schema
        assert orders_schema.properties.key?("product_id"), "orders route should have product_id"
        assert orders_schema.properties.key?("quantity"), "orders route should have quantity"
        refute orders_schema.properties.key?("user_name"), "orders route should NOT have user_name"
        refute orders_schema.properties.key?("title"), "orders route should NOT have title"

        # Verify /articles route has title and body fields
        articles_schema = articles_op.request_body.media_types.first.schema
        assert articles_schema.properties.key?("title"), "articles route should have title"
        assert articles_schema.properties.key?("body"), "articles route should have body"
        refute articles_schema.properties.key?("user_name"), "articles route should NOT have user_name"
        refute articles_schema.properties.key?("product_id"), "articles route should NOT have product_id"
      end
    end
  end
end
