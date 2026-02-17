# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsNestedTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Simple nested hash (1 level) ===

      def test_nested_hash_creates_object_property
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :address, type: Hash do
              requires :street, type: String
              requires :city, type: String
              optional :zip, type: String
            end
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_equal "object", body_schema.type
        assert_includes body_schema.properties.keys, "address"

        address = body_schema.properties["address"]

        assert_equal "object", address.type
        assert_equal %w[city street zip].sort, address.properties.keys.sort
        assert_equal "string", address.properties["street"].type
        assert_equal "string", address.properties["city"].type
        assert_equal "string", address.properties["zip"].type
      end

      def test_nested_hash_propagates_required_fields
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :address, type: Hash do
              requires :street, type: String
              optional :apartment, type: String
            end
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        address = body_schema.properties["address"]

        assert_includes address.required, "street"
        refute_includes address.required, "apartment"
      end

      def test_nested_hash_with_typed_fields
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :dimensions, type: Hash do
              requires :width, type: Integer
              requires :height, type: Integer
              optional :depth, type: Float
            end
          end
          post "products" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        dimensions = body_schema.properties["dimensions"]

        assert_equal "integer", dimensions.properties["width"].type
        assert_equal "integer", dimensions.properties["height"].type
        assert_equal "number", dimensions.properties["depth"].type
      end

      # === Multiple nested hashes at same level ===

      def test_multiple_nested_hashes_at_same_level
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :billing_address, type: Hash do
              requires :street, type: String
              requires :city, type: String
            end
            requires :shipping_address, type: Hash do
              requires :street, type: String
              requires :city, type: String
              optional :notes, type: String
            end
          end
          post "orders" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_includes body_schema.properties.keys, "billing_address"
        assert_includes body_schema.properties.keys, "shipping_address"

        billing = body_schema.properties["billing_address"]
        shipping = body_schema.properties["shipping_address"]

        assert_equal "object", billing.type
        assert_equal "object", shipping.type
        assert_equal %w[city street].sort, billing.properties.keys.sort
        assert_equal %w[city notes street].sort, shipping.properties.keys.sort
      end

      # === Deep nesting (2+ levels) ===

      def test_deeply_nested_hash_structures
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :company, type: Hash do
              requires :name, type: String
              requires :address, type: Hash do
                requires :street, type: String
                requires :city, type: String
                optional :geo, type: Hash do
                  requires :lat, type: Float
                  requires :lng, type: Float
                end
              end
            end
          end
          post "companies" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        company = body_schema.properties["company"]

        assert_equal "object", company.type
        assert_includes company.properties.keys, "name"
        assert_includes company.properties.keys, "address"

        address = company.properties["address"]

        assert_equal "object", address.type
        assert_includes address.properties.keys, "street"
        assert_includes address.properties.keys, "city"
        assert_includes address.properties.keys, "geo"

        geo = address.properties["geo"]

        assert_equal "object", geo.type
        assert_equal "number", geo.properties["lat"].type
        assert_equal "number", geo.properties["lng"].type
      end

      def test_deeply_nested_required_propagation
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :outer, type: Hash do
              requires :middle, type: Hash do
                requires :inner_required, type: String
                optional :inner_optional, type: String
              end
            end
          end
          post "nested" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        outer = body_schema.properties["outer"]
        middle = outer.properties["middle"]

        assert_includes outer.required, "middle"
        assert_includes middle.required, "inner_required"
        refute_includes middle.required, "inner_optional"
      end

      # === Mixed nested structures (Hash with primitives and nested Hash) ===

      def test_mixed_primitive_and_nested_hash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :user, type: Hash do
              requires :name, type: String
              requires :age, type: Integer
              optional :profile, type: Hash do
                optional :bio, type: String
                optional :website, type: String
              end
            end
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        user = body_schema.properties["user"]

        assert_equal "string", user.properties["name"].type
        assert_equal "integer", user.properties["age"].type
        assert_equal "object", user.properties["profile"].type
        assert_includes user.properties["profile"].properties.keys, "bio"
      end

      # === Optional nested hash ===

      def test_optional_nested_hash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String
            optional :metadata, type: Hash do
              optional :source, type: String
              optional :tags, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_includes body_schema.required, "name"
        refute_includes body_schema.required, "metadata"

        metadata = body_schema.properties["metadata"]

        assert_equal "object", metadata.type
      end

      # === GET requests with nested params (query param flattening) ===

      def test_get_request_flattens_nested_hash_to_query_params
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String
            optional :tax_id, type: Hash do
              requires :type, type: String, documentation: { desc: "The TaxId type" }
              requires :value, type: String, documentation: { desc: "The TaxId value" }
            end
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        # Should have flat params including bracket notation for nested hash
        param_names = params.map(&:name)

        assert_includes param_names, "name"
        assert_includes param_names, "tax_id[type]"
        assert_includes param_names, "tax_id[value]"

        # Check locations are all query
        params.each do |param|
          assert_equal "query", param.location
        end

        # Check descriptions are preserved
        type_param = params.find { |p| p.name == "tax_id[type]" }
        value_param = params.find { |p| p.name == "tax_id[value]" }

        assert_equal "The TaxId type", type_param.description
        assert_equal "The TaxId value", value_param.description
      end

      def test_get_request_with_deeply_nested_hash_flattens_correctly
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :address, type: Hash do
              requires :country, type: String
              optional :geo, type: Hash do
                requires :lat, type: Float
                requires :lng, type: Float
              end
            end
          end
          get "locations" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param_names = params.map(&:name)

        assert_includes param_names, "address[country]"
        assert_includes param_names, "address[geo][lat]"
        assert_includes param_names, "address[geo][lng]"
      end

      def test_post_request_keeps_nested_in_body_not_query
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :tax_id, type: Hash do
              requires :type, type: String
              requires :value, type: String
            end
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # No query params for nested structure in POST
        param_names = params.map(&:name)

        refute_includes param_names, "tax_id[type]"
        refute_includes param_names, "tax_id[value]"

        # Should be in body schema instead
        assert_includes body_schema.properties.keys, "tax_id"
      end

      def test_get_request_with_explicit_request_body_keeps_nested_in_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: Hash do
              requires :field, type: String
              requires :operator, type: String
              requires :value, type: String
            end
          end
          get "search", documentation: { request_body: true } do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # No query params for nested structure when request_body is enabled
        param_names = params.map(&:name)

        refute_includes param_names, "filter[field]"
        refute_includes param_names, "filter[operator]"
        refute_includes param_names, "filter[value]"

        # Should be in body schema instead
        assert_includes body_schema.properties.keys, "filter"

        filter_schema = body_schema.properties["filter"]

        assert_equal "object", filter_schema.type
        assert_includes filter_schema.properties.keys, "field"
        assert_includes filter_schema.properties.keys, "operator"
        assert_includes filter_schema.properties.keys, "value"
      end

      def test_get_request_with_in_body_documentation_keeps_nested_in_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: Hash, documentation: { in: "body" } do
              requires :field, type: String
              requires :operator, type: String
            end
          end
          get "search" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # No query params for nested structure when in: 'body' is set
        param_names = params.map(&:name)

        refute_includes param_names, "filter[field]"
        refute_includes param_names, "filter[operator]"

        # Should be in body schema instead
        assert_includes body_schema.properties.keys, "filter"
      end

      def test_get_request_with_param_type_body_keeps_nested_in_body
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :data, type: Hash, documentation: { param_type: "body" } do
              requires :name, type: String
              requires :value, type: String
            end
          end
          get "fetch" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # No query params for nested structure when param_type: 'body' is set
        param_names = params.map(&:name)

        refute_includes param_names, "data[name]"
        refute_includes param_names, "data[value]"

        # Should be in body schema instead
        assert_includes body_schema.properties.keys, "data"
      end

      def test_delete_request_flattens_nested_to_query_by_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :options, type: Hash do
              optional :cascade, type: Grape::API::Boolean
              optional :force, type: Grape::API::Boolean
            end
          end
          delete "items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param_names = params.map(&:name)

        assert_includes param_names, "options[cascade]"
        assert_includes param_names, "options[force]"
      end

      # === Nullable nested hash via documentation: { x: { nullable: true } } ===

      def test_nested_hash_with_x_nullable_documentation_sets_nullable
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :response_settings, type: Hash, documentation: { x: { nullable: true } } do
              requires :format, type: String
              requires :policy, type: String
            end
          end
          post "choices" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        response_settings = body_schema.properties["response_settings"]

        assert_equal "object", response_settings.type
        assert response_settings.nullable, "Expected response_settings schema to be nullable"
      end

      def test_nested_hash_without_nullable_documentation_is_not_nullable
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :settings, type: Hash do
              requires :key, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        settings = body_schema.properties["settings"]

        assert_equal "object", settings.type
        refute settings.nullable, "Expected settings schema to NOT be nullable"
      end

      def test_nested_hash_with_direct_nullable_documentation_sets_nullable
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :metadata, type: Hash, documentation: { nullable: true } do
              requires :key, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        metadata = body_schema.properties["metadata"]

        assert metadata.nullable, "Expected metadata schema to be nullable"
      end

      def test_head_request_flattens_nested_to_query_by_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: Hash do
              optional :status, type: String
              optional :active, type: Grape::API::Boolean
            end
          end
          head "resources" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param_names = params.map(&:name)

        assert_includes param_names, "filter[status]"
        assert_includes param_names, "filter[active]"
      end
    end
  end
end
