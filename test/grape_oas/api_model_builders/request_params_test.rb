# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_extracts_path_parameters
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, type: Integer, desc: "User ID"
          end
          get "users/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        id_param = params.find { |p| p.name == "id" }

        assert_equal "path", id_param.location
        assert id_param.required
      end

      def test_extracts_query_parameters
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: String, desc: "Filter query"
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        filter_param = params.find { |p| p.name == "filter" }

        assert_equal "query", filter_param.location
        refute filter_param.required
      end

      def test_maps_integer_type
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :count, type: Integer
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        count_param = params.find { |p| p.name == "count" }

        assert_equal "integer", count_param.schema.type
      end

      def test_maps_float_type_to_number
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :price, type: Float
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        price_param = params.find { |p| p.name == "price" }

        assert_equal "number", price_param.schema.type
      end

      def test_maps_boolean_type
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :active, type: Grape::API::Boolean
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        active_param = params.find { |p| p.name == "active" }

        assert_equal "boolean", active_param.schema.type
      end

      def test_defaults_unknown_types_to_string
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :data, type: Symbol
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        data_param = params.find { |p| p.name == "data" }

        assert_equal "string", data_param.schema.type
      end

      def test_respects_documentation_param_type
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :api_key, type: String, documentation: { param_type: "header" }
          end
          get "secure" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        api_key_param = params.find { |p| p.name == "api_key" }

        assert_equal "header", api_key_param.location
      end

      def test_accumulates_body_parameters
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String, documentation: { param_type: "body" }
            requires :email, type: String, documentation: { param_type: "body" }
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_equal "object", body_schema.type
        assert_equal 2, body_schema.properties.size
        assert_equal %w[email name].sort, body_schema.properties.keys.sort
        assert_includes body_schema.required, "name"
        assert_includes body_schema.required, "email"
      end

      def test_extracts_parameter_description
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String, documentation: { desc: "The user name" }
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        name_param = params.find { |p| p.name == "name" }

        assert_equal "The user name", name_param.description
      end

      def test_sets_nullable_from_allow_nil
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :note, type: String, documentation: { nullable: true }
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        note_param = params.find { |p| p.name == "note" }

        assert note_param.schema.nullable
      end

      class EP < Grape::Entity
        expose :name, documentation: { type: String, desc: "Name" }
        expose :age, documentation: { type: Integer }
      end

      def test_entity_param_in_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :profile, type: EP, documentation: { param_type: "body" }
          end
          post "profiles" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        assert body_schema.properties["profile"]
        profile = body_schema.properties["profile"]

        assert_equal "object", profile.type
        assert_equal %w[age name].sort, profile.properties.keys.sort
        assert_empty params
      end

      def test_array_of_entity_param_in_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :profiles, type: Array, documentation: { param_type: "body", type: EP, is_array: true }
          end
          post "profiles/bulk" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        profiles = body_schema.properties["profiles"]

        assert_equal "array", profiles.type
        assert_equal %w[age name].sort, profiles.items.properties.keys.sort
        assert_empty params
      end

      # === Additional type scenarios ===

      def test_typed_array_string_notation
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

      def test_typed_array_integer_notation
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

      def test_hash_type_parameter
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :metadata, type: Hash, documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        metadata = body_schema.properties["metadata"]

        assert_equal "object", metadata.type
      end

      def test_bigdecimal_type_maps_to_number
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :amount, type: BigDecimal
          end
          get "prices" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        amount_param = params.find { |p| p.name == "amount" }

        assert_equal "number", amount_param.schema.type
      end
    end
  end
end
