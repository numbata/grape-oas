# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class ResponseTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_builds_default_200_response
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build
        response = responses.first

        assert_equal "200", response.http_status
        assert_equal "Success", response.description
      end

      def test_builds_media_type_for_json
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        response = builder.build.first

        assert_equal 1, response.media_types.size
        media_type = response.media_types.first

        assert_equal "application/json", media_type.mime_type
      end

      def test_builds_string_schema_when_no_entity
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        response = builder.build.first

        schema = response.media_types.first.schema

        assert_equal "string", schema.type
      end

      def test_builds_object_schema_with_entity
        entity_class = Class.new(Grape::Entity) do
          expose :id
          expose :name
        end
        Object.const_set(:NamedUserEntity, entity_class) unless defined?(NamedUserEntity)

        api_class = Class.new(Grape::API) do
          format :json
          get "users", entity: NamedUserEntity do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        response = builder.build.first

        schema = response.media_types.first.schema

        assert_equal "object", schema.type
        assert_equal "NamedUserEntity", schema.canonical_name
      end

      def test_sets_canonical_name_from_entity_class
        entity_class = Class.new(Grape::Entity)
        # Give it a name for testing
        Object.const_set(:TestUserEntity, entity_class) unless defined?(TestUserEntity)

        api_class = Class.new(Grape::API) do
          format :json
          get "users", entity: TestUserEntity do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        response = builder.build.first

        schema = response.media_types.first.schema

        assert_equal "TestUserEntity", schema.canonical_name
      end

      def test_builds_multiple_responses_from_success_and_failure
        entity_class = Class.new(Grape::Entity)
        api_class = Class.new(Grape::API) do
          format :json
          desc "Create user",
               success: { code: 201, message: "Created" },
               failure: [[422, "Unprocessable"]]
          post "users", entity: entity_class do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        codes = responses.map(&:http_status)

        assert_includes codes, "201"
        assert_includes codes, "422"
      end

      def test_uses_documentation_responses_and_headers
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user", documentation: {
            responses: {
              201 => { message: "Created", "x-rate-limit" => 10 },
              422 => { message: "Invalid", headers: { "X-Error" => { desc: "reason", type: "string" } } }
            },
            headers: { "X-Trace" => { desc: "trace id", type: "string" } }
          }
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        codes = responses.map(&:http_status)

        assert_includes codes, "201"
        assert_includes codes, "422"

        hdrs_422 = responses.find { |r| r.http_status == "422" }.headers

        assert_equal "X-Error", hdrs_422.first[:name]

        resp_201 = responses.find { |r| r.http_status == "201" }
        hdrs_default = resp_201.headers

        assert_equal "X-Trace", hdrs_default.first[:name]
        assert_equal 10, resp_201.extensions[:"x-rate-limit"]
      end
    end
  end
end
