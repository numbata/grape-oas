# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsMultiTypeTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Multi-type parameters (types: [String, Integer]) ===

      def test_multi_type_generates_one_of_schema
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :input, types: [String, Integer], desc: "Multi-type input"
          end
          get("test") { {} }
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param = params.find { |p| p.name == "input" }

        assert_equal "query", param.location
        assert param.required

        # Should have oneOf with two schemas
        assert_nil param.schema.type
        assert_equal 2, param.schema.one_of.size
        assert_equal Constants::SchemaTypes::STRING, param.schema.one_of[0].type
        assert_equal Constants::SchemaTypes::INTEGER, param.schema.one_of[1].type
      end

      def test_multi_type_with_float
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :value, types: [String, Float]
          end
          get("test") { {} }
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param = params.find { |p| p.name == "value" }

        assert_equal 2, param.schema.one_of.size
        assert_equal Constants::SchemaTypes::STRING, param.schema.one_of[0].type
        assert_equal Constants::SchemaTypes::NUMBER, param.schema.one_of[1].type
      end

      def test_multi_type_with_three_types
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, types: [String, Integer, Float]
          end
          get("test") { {} }
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param = params.find { |p| p.name == "id" }

        assert_equal 3, param.schema.one_of.size
        assert_equal Constants::SchemaTypes::STRING, param.schema.one_of[0].type
        assert_equal Constants::SchemaTypes::INTEGER, param.schema.one_of[1].type
        assert_equal Constants::SchemaTypes::NUMBER, param.schema.one_of[2].type
      end

      def test_multi_type_with_boolean
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :flag, types: [String, Grape::API::Boolean]
          end
          get("test") { {} }
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param = params.find { |p| p.name == "flag" }

        assert_equal 2, param.schema.one_of.size
        assert_equal Constants::SchemaTypes::STRING, param.schema.one_of[0].type
        assert_equal Constants::SchemaTypes::BOOLEAN, param.schema.one_of[1].type
      end

      # Make sure we don't break typed arrays like "[String]"
      def test_typed_array_still_works
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :tags, type: "[String]"
          end
          get("test") { {} }
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param = params.find { |p| p.name == "tags" }

        # Should be an array, not oneOf
        assert_equal Constants::SchemaTypes::ARRAY, param.schema.type
        assert_nil param.schema.one_of
        assert_equal Constants::SchemaTypes::STRING, param.schema.items.type
      end
    end
  end
end
