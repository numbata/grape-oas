# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsArrayTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Typed Array parameters ===

      def test_array_of_strings
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :tags, type: Array[String], documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        tags = body_schema.properties["tags"]

        assert_equal "array", tags.type
        assert_equal "string", tags.items.type
      end

      def test_array_of_integers
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :ids, type: Array[Integer], documentation: { param_type: "body" }
          end
          post "batch" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        ids = body_schema.properties["ids"]

        assert_equal "array", ids.type
        assert_equal "integer", ids.items.type
      end

      def test_untyped_array_defaults_to_string_items
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :values, type: Array, documentation: { param_type: "body" }
          end
          post "data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        values = body_schema.properties["values"]

        assert_equal "array", values.type
        refute_nil values.items
        assert_equal "string", values.items.type
      end

      # === Array of objects (nested structure) ===

      def test_array_of_objects_with_nested_params
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :items, type: Array do
              requires :id, type: Integer
              requires :name, type: String
            end
          end
          post "orders" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        items = body_schema.properties["items"]

        assert_equal "array", items.type
        assert_equal "object", items.items.type
        assert_includes items.items.properties.keys, "id"
        assert_includes items.items.properties.keys, "name"
        assert_equal "integer", items.items.properties["id"].type
        assert_equal "string", items.items.properties["name"].type
      end

      def test_array_of_objects_propagates_required
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :entries, type: Array do
              requires :key, type: String
              optional :value, type: String
            end
          end
          post "config" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        entries = body_schema.properties["entries"]

        assert_includes entries.items.required, "key"
        refute_includes entries.items.required, "value"
      end

      # === Multiple arrays ===

      def test_multiple_array_params
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :tags, type: Array[String], documentation: { param_type: "body" }
            requires :categories, type: Array[Integer], documentation: { param_type: "body" }
          end
          post "multi" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_includes body_schema.properties.keys, "tags"
        assert_includes body_schema.properties.keys, "categories"
        assert_equal "array", body_schema.properties["tags"].type
        assert_equal "array", body_schema.properties["categories"].type
      end

      # === Optional array ===

      def test_optional_array
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String, documentation: { param_type: "body" }
            optional :flags, type: Array[String], documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_includes body_schema.required, "name"
        refute_includes body_schema.required, "flags"
      end

      # === Array in query params ===

      def test_array_as_query_param
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :ids, type: Array[Integer], documentation: { param_type: "query" }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        ids_param = params.find { |p| p.name == "ids" }

        assert_equal "query", ids_param.location
        assert_equal "array", ids_param.schema.type
        assert_equal "integer", ids_param.schema.items.type
      end

      # === Deeply nested arrays ===

      def test_array_containing_nested_hash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :users, type: Array do
              requires :name, type: String
              requires :address, type: Hash do
                requires :city, type: String
              end
            end
          end
          post "bulk" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        users = body_schema.properties["users"]

        assert_equal "array", users.type
        assert_equal "object", users.items.type
        assert_includes users.items.properties.keys, "name"
        assert_includes users.items.properties.keys, "address"

        address = users.items.properties["address"]

        assert_equal "object", address.type
        assert_includes address.properties.keys, "city"
      end
    end
  end
end
