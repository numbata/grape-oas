# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsBodyTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === POST params go to body by default when nested ===

      def test_post_nested_params_go_to_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :user, type: Hash do
              requires :name, type: String
              requires :email, type: String
            end
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        assert_includes body_schema.properties.keys, "user"
        assert_empty params, "Non-path params should be in body, not in params array"
      end

      # === GET params stay as query ===

      def test_get_params_are_query_by_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: String
            optional :page, type: Integer
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        filter_param = params.find { |p| p.name == "filter" }
        page_param = params.find { |p| p.name == "page" }

        assert_equal "query", filter_param.location
        assert_equal "query", page_param.location
      end

      # === PUT/PATCH nested params go to body ===

      def test_put_nested_params_go_to_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, type: Integer, desc: "Article ID"
            requires :article, type: Hash do
              requires :title, type: String
              optional :content, type: String
            end
          end
          put "articles/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        assert_includes body_schema.properties.keys, "article"
        # Path param should still be in params
        id_param = params.find { |p| p.name == "id" }

        assert_equal "path", id_param.location
      end

      def test_patch_nested_params_go_to_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, type: Integer, desc: "User ID"
            optional :settings, type: Hash do
              optional :theme, type: String
              optional :language, type: String
            end
          end
          patch "users/:id/settings" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        assert_includes body_schema.properties.keys, "settings"
        id_param = params.find { |p| p.name == "id" }

        assert_equal "path", id_param.location
      end

      # === Explicit param_type overrides default ===

      def test_explicit_query_param_in_post
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :data, type: Hash do
              requires :value, type: String
            end
            optional :format, type: String, documentation: { param_type: "query" }
          end
          post "process" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # data should be in body
        assert_includes body_schema.properties.keys, "data"

        # format should be query param
        format_param = params.find { |p| p.name == "format" }

        assert_equal "query", format_param.location
      end

      def test_explicit_header_param
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :payload, type: Hash do
              requires :content, type: String
            end
            requires :x_api_key, type: String, documentation: { param_type: "header" }
          end
          post "secure" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # payload should be in body
        assert_includes body_schema.properties.keys, "payload"

        # x_api_key should be header param
        api_key_param = params.find { |p| p.name == "x_api_key" }

        assert_equal "header", api_key_param.location
      end

      # === Path params are always path ===

      def test_path_params_not_affected_by_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, type: Integer, desc: "Resource ID"
            requires :data, type: Hash do
              requires :name, type: String
            end
          end
          put "resources/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        id_param = params.find { |p| p.name == "id" }

        assert_equal "path", id_param.location
        assert_includes body_schema.properties.keys, "data"
      end

      # === Mixed params with nested structures ===

      def test_mixed_query_and_body_with_nested
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :dry_run, type: Grape::API::Boolean, documentation: { param_type: "query" }
            requires :order, type: Hash do
              requires :items, type: Array do
                requires :product_id, type: Integer
                requires :quantity, type: Integer
              end
              optional :notes, type: String
            end
          end
          post "orders" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # dry_run should be query
        dry_run_param = params.find { |p| p.name == "dry_run" }

        assert_equal "query", dry_run_param.location

        # order should be in body with nested structure
        assert_includes body_schema.properties.keys, "order"
        order = body_schema.properties["order"]

        assert_includes order.properties.keys, "items"
        assert_includes order.properties.keys, "notes"
      end
    end
  end
end
