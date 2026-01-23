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
            requires :tags, type: [String], documentation: { param_type: "body" }
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
            requires :ids, type: [Integer], documentation: { param_type: "body" }
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
            requires :tags, type: [String], documentation: { param_type: "body" }
            requires :categories, type: [Integer], documentation: { param_type: "body" }
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
            optional :flags, type: [String], documentation: { param_type: "body" }
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
            optional :ids, type: [Integer], documentation: { param_type: "query" }
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

      # === Collection format ===

      def test_collection_format_from_documentation
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :statuses, type: [String], documentation: { param_type: "query", collectionFormat: "multi" }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        statuses_param = params.find { |p| p.name == "statuses" }

        assert_equal "multi", statuses_param.collection_format
      end

      def test_collection_format_snake_case
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :tags, type: [String], documentation: { param_type: "query", collection_format: "csv" }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        tags_param = params.find { |p| p.name == "tags" }

        assert_equal "csv", tags_param.collection_format
      end

      def test_collection_format_nil_by_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :ids, type: [Integer], documentation: { param_type: "query" }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        ids_param = params.find { |p| p.name == "ids" }

        assert_nil ids_param.collection_format
      end

      # === Namespaced types ===

      def test_array_of_namespaced_type_with_uuid
        # Simulate what Grape stores when you use type: [MyModule::Types::UUID]
        # Grape converts this to the string "[MyModule::Types::UUID]"
        api_class = Class.new(Grape::API) do
          format :json
          params do
            # Using a string that simulates namespaced type (Grape stringifies these)
            requires :slide_ids, type: "[MyModule::Types::UUID]", documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        slide_ids = body_schema.properties["slide_ids"]

        assert_equal "array", slide_ids.type
        assert_equal "string", slide_ids.items.type
        assert_equal "uuid", slide_ids.items.format
      end

      def test_array_of_namespaced_type_with_datetime
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :timestamps, type: "[MyModule::Types::DateTime]", documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        timestamps = body_schema.properties["timestamps"]

        assert_equal "array", timestamps.type
        assert_equal "string", timestamps.items.type
        assert_equal "date-time", timestamps.items.format
      end

      def test_array_of_deeply_namespaced_type
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :ids, type: "[Very::Deeply::Nested::Module::Type]", documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        ids = body_schema.properties["ids"]

        assert_equal "array", ids.type
        # Unknown namespaced types default to string
        assert_equal "string", ids.items.type
      end

      # === Entity arrays ===

      def test_array_of_entity_in_typed_notation
        # Define an entity class for testing
        user_entity = Class.new(Grape::Entity) do
          expose :id, documentation: { type: Integer }
          expose :name, documentation: { type: String }
        end

        # Make the entity accessible via const_get
        Object.const_set(:TestUserEntityForArray, user_entity) unless defined?(TestUserEntityForArray)

        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :users, type: "[TestUserEntityForArray]", documentation: { param_type: "body" }
          end
          post "batch" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        users = body_schema.properties["users"]

        assert_equal "array", users.type
        # Items should be an object schema from the entity introspector
        assert_equal "object", users.items.type
        assert users.items.properties.key?("id")
        assert users.items.properties.key?("name")
      end
    end
  end
end
