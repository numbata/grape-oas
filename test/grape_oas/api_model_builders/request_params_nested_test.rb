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
    end
  end
end
