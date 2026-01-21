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

      def test_request_body_and_content_extensions_from_documentation
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:foo).filled(:string)
          end

          desc "Create",
               contract: contract,
               documentation: {
                 "x-req" => "rb",
                 content: {
                   "application/json" => { "x-ct" => "ct" }
                 }
               }
          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        rb = operation.request_body

        assert_equal "rb", rb.extensions["x-req"]
        mt = rb.media_types.first

        assert_equal "ct", mt.extensions["x-ct"]
      end

      def test_media_type_extensions_with_symbol_key
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:foo).filled(:string)
          end

          desc "Create",
               contract: contract,
               documentation: {
                 content: {
                   "application/json": { "x-ct" => "symbol_key" }
                 }
               }
          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_equal "symbol_key", mt.extensions["x-ct"]
      end

      def test_no_media_type_extensions_when_content_not_hash
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:foo).filled(:string)
          end

          desc "Create",
               contract: contract,
               documentation: { content: "not a hash" }
          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_nil mt.extensions
      end

      def test_no_media_type_extensions_when_mime_not_found
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:foo).filled(:string)
          end

          desc "Create",
               contract: contract,
               documentation: {
                 content: {
                   "text/plain" => { "x-ct" => "different_mime" }
                 }
               }
          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_nil mt.extensions
      end

      def test_no_request_body_extensions_when_no_x_prefixed
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:foo).filled(:string)
          end

          desc "Create",
               contract: contract,
               documentation: { "regular" => "value" }
          post "/items" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        rb = operation.request_body

        assert_nil rb.extensions
      end

      def test_request_body_for_get_when_explicitly_allowed
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:query).filled(:string)
          end

          desc "Search",
               contract: contract,
               documentation: { request_body: true }
          get "/search" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "GET should have request body when explicitly allowed"
      end

      def test_request_body_for_delete_when_explicitly_allowed_via_option
        api_class = Class.new(Grape::API) do
          format :json

          contract = Dry::Schema.Params do
            required(:ids).array(:integer)
          end

          desc "Bulk delete",
               contract: contract,
               request_body: true
          delete "/items/bulk" do
            {}
          end
        end

        route = api_class.routes.first
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :delete)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "DELETE should have request body when explicitly allowed"
      end

      def test_contract_from_route_settings
        # Contracts can be stored in route.settings[:contract] for mounted APIs or legacy configuration
        contract = Struct.new(:to_h).new({ name: String, email: String })
        route_with_settings = Struct.new(:options, :path, :settings).new(
          { params: {} },
          "/items",
          { contract: contract }
        )

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route_with_settings, operation: operation).build

        refute_nil operation.request_body, "Should build request body from route.settings[:contract]"
        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "name"
        assert_includes schema.properties.keys, "email"
      end

      def test_contract_from_route_options_schema
        # Contracts can also be provided via desc "...", schema: MySchema
        contract = Struct.new(:to_h).new({ title: String })
        route = Struct.new(:options, :path, :settings).new(
          { schema: contract, params: {} },
          "/items",
          {}
        )

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "Should build request body from route.options[:schema]"
        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "title"
      end
    end
  end
end
