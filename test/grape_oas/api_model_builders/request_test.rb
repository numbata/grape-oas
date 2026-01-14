# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_builds_request_body_from_dry_schema_contract
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:filter).array(:hash) do
              required(:field).filled(:string)
              required(:value).filled(:string)
            end
            optional(:sort).filled(:string)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body
        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "filter"
        assert_equal "array", schema.properties["filter"].type
      end

      def test_contract_nullable_field
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            optional(:note).maybe(:string)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema
        note = schema.properties["note"]

        assert note.nullable
      end

      def test_contract_with_nested_hash
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:address).hash do
              required(:street).filled(:string)
              required(:city).filled(:string)
            end
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema
        address_schema = schema.properties["address"]

        assert_equal "object", address_schema.type
        assert_includes address_schema.properties.keys, "street"
        assert_includes address_schema.properties.keys, "city"
        assert_equal "string", address_schema.properties["street"].type
      end

      def test_contract_with_validation_contract
        test_contract = Class.new(Dry::Validation::Contract) do
          params do
            required(:name).filled(:string)
            optional(:email).maybe(:string)
          end
        end

        api_class = Class.new(Grape::API) do
          format :json

          contract test_contract

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "name"
        assert_equal "string", schema.properties["name"].type
      end

      def test_no_request_body_when_no_contract
        api_class = Class.new(Grape::API) do
          format :json

          get "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body
      end

      def test_no_request_body_for_get_by_default
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:query).filled(:string)
          end

          get "/search" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "GET should not have request body by default"
      end

      def test_no_request_body_for_delete_by_default
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:id).filled(:integer)
          end

          delete "/items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :delete)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "DELETE should not have request body by default"
      end

      def test_no_request_body_for_head_by_default
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:query).filled(:string)
          end

          head "/status" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :head)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "HEAD should not have request body by default"
      end

      def test_request_body_for_post
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:name).filled(:string)
          end

          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "POST should have request body"
      end

      def test_request_body_for_put
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            required(:name).filled(:string)
          end

          put "/items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :put)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "PUT should have request body"
      end

      def test_request_body_for_patch
        api_class = Class.new(Grape::API) do
          format :json

          contract Dry::Schema.Params do
            optional(:name).filled(:string)
          end

          patch "/items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :patch)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "PATCH should have request body"
      end
    end
  end
end
