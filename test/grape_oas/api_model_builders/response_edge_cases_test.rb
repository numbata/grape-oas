# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class ResponseEdgeCasesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Response Entity for tests ===

      class ItemEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :name, documentation: { type: String }
      end

      class ErrorEntity < Grape::Entity
        expose :code, documentation: { type: Integer }
        expose :message, documentation: { type: String }
      end

      # === Multiple status codes with different entities ===

      def test_multiple_failure_status_codes
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get item",
               success: { code: 200, model: ResponseEdgeCasesTest::ItemEntity },
               failure: [
                 [400, "Bad Request", ResponseEdgeCasesTest::ErrorEntity],
                 [404, "Not Found", ResponseEdgeCasesTest::ErrorEntity],
                 [500, "Internal Server Error"]
               ]
          get "items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        # Should have success response
        success_response = responses.find { |r| r.http_status == "200" }

        refute_nil success_response

        # Should have failure responses
        bad_request = responses.find { |r| r.http_status == "400" }
        not_found = responses.find { |r| r.http_status == "404" }
        server_error = responses.find { |r| r.http_status == "500" }

        refute_nil bad_request, "Should have 400 response"
        refute_nil not_found, "Should have 404 response"
        refute_nil server_error, "Should have 500 response"

        assert_equal "Bad Request", bad_request.description
        assert_equal "Not Found", not_found.description
      end

      # === 204 No Content response should have no schema ===

      def test_204_no_content_response
        api_class = Class.new(Grape::API) do
          format :json
          desc "Delete item",
               success: { code: 204, message: "No Content" },
               failure: [[404, "Not Found", ResponseEdgeCasesTest::ErrorEntity]]
          delete "items/:id" do
            status 204
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        no_content = responses.find { |r| r.http_status == "204" }

        refute_nil no_content, "Should have 204 response"
        assert_equal "No Content", no_content.description
      end

      # === Response with headers ===

      def test_response_with_headers
        api_class = Class.new(Grape::API) do
          format :json
          desc "Create item", documentation: {
            responses: {
              200 => {
                message: "Created",
                headers: {
                  "Location" => { description: "URL of the created item", type: "string" },
                  "X-Request-Id" => { description: "Request tracking ID", type: "string" }
                }
              }
            }
          }
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        success = responses.find { |r| r.http_status == "200" }

        refute_nil success
        refute_nil success.headers
        header_names = success.headers.map { |h| h[:name] }

        assert_includes header_names, "Location"
        assert_includes header_names, "X-Request-Id"
      end

      # === Multiple success responses (201 Created, 200 OK) ===

      def test_multiple_success_status_codes
        api_class = Class.new(Grape::API) do
          format :json
          desc "Create or update item",
               success: [
                 { code: 200, message: "Updated" },
                 { code: 201, message: "Created" }
               ]
          put "items/:id", entity: ResponseEdgeCasesTest::ItemEntity do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        ok_response = responses.find { |r| r.http_status == "200" }
        created_response = responses.find { |r| r.http_status == "201" }

        refute_nil ok_response, "Should have 200 response"
        refute_nil created_response, "Should have 201 response"
        assert_equal "Updated", ok_response.description
        assert_equal "Created", created_response.description
      end

      # === Response with array of entities ===

      def test_response_with_array_of_entities
        api_class = Class.new(Grape::API) do
          format :json
          desc "List items",
               success: { code: 200, model: ResponseEdgeCasesTest::ItemEntity, is_array: true }
          get "items" do
            []
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        success = responses.find { |r| r.http_status == "200" }

        refute_nil success
        schema = success.media_types.first.schema

        # NOTE: is_array handling depends on implementation
        refute_nil schema
      end

      # === Empty success (no entity) ===

      def test_response_without_entity
        api_class = Class.new(Grape::API) do
          format :json
          desc "Ping endpoint"
          get "ping" do
            { status: "ok" }
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        # Should still have a default response even without entity
        refute_empty responses
      end

      # === Deprecated endpoint response ===

      def test_deprecated_endpoint_response
        api_class = Class.new(Grape::API) do
          format :json
          desc "Old endpoint", deprecated: true
          get "old/items", entity: ResponseEdgeCasesTest::ItemEntity do
            {}
          end
        end

        route = api_class.routes.first

        # Test that deprecated is accessible
        assert route.options[:deprecated],
               "Deprecated flag should be set on route"
      end

      # === Failure with entities ===

      def test_failure_response_with_entity
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get secured item",
               success: { code: 200, model: ResponseEdgeCasesTest::ItemEntity },
               failure: [
                 [401, "Unauthorized"],
                 [403, "Forbidden"],
                 [404, "Not Found", ResponseEdgeCasesTest::ErrorEntity]
               ]
          get "secured/items/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        unauthorized = responses.find { |r| r.http_status == "401" }
        forbidden = responses.find { |r| r.http_status == "403" }
        not_found = responses.find { |r| r.http_status == "404" }

        refute_nil unauthorized, "Should have 401 response"
        refute_nil forbidden, "Should have 403 response"
        refute_nil not_found, "Should have 404 response"

        # 404 with entity should have schema with properties
        schema_404 = not_found.media_types.first.schema

        assert_equal "object", schema_404.type
        assert_includes schema_404.properties.keys, "code"
        assert_includes schema_404.properties.keys, "message"
      end

      # === Multiple Present Response Tests ===

      class UserEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :email, documentation: { type: String }
      end

      class ProfileEntity < Grape::Entity
        expose :bio, documentation: { type: String }
        expose :avatar_url, documentation: { type: String }
      end

      def test_multiple_present_response_with_as_keys
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user with profile",
               success: [
                 { model: ResponseEdgeCasesTest::UserEntity, as: :user },
                 { model: ResponseEdgeCasesTest::ProfileEntity, as: :profile }
               ]
          get "users/:id/full" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        # Should have single 200 response with merged schema
        assert_equal 1, responses.size
        response = responses.first

        assert_equal "200", response.http_status
        schema = response.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "user"
        assert_includes schema.properties.keys, "profile"
      end

      def test_multiple_present_response_with_one_of
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user or profile",
               success: {
                 one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity },
                   { model: ResponseEdgeCasesTest::ProfileEntity }
                 ]
               }
          get "users/:id/flexible" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        assert_equal 1, responses.size
        response = responses.first

        assert_equal "200", response.http_status
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::UserEntity", schema.one_of[0].canonical_name
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::ProfileEntity", schema.one_of[1].canonical_name
      end

      def test_multiple_present_response_with_one_of_array_syntax
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user or profile",
               success: [
                 {
                   one_of: [
                     { model: ResponseEdgeCasesTest::UserEntity },
                     { model: ResponseEdgeCasesTest::ProfileEntity }
                   ]
                 }
               ]
          get "users/:id/flexible2" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        assert_equal 1, responses.size
        response = responses.first

        assert_equal "200", response.http_status
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::UserEntity", schema.one_of[0].canonical_name
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::ProfileEntity", schema.one_of[1].canonical_name
      end

      def test_one_of_with_mixed_as_keys
        api_class = Class.new(Grape::API) do
          format :json
          desc "Mixed oneOf with as",
               success: [{
                 one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity, as: "Model1" },
                   { model: ResponseEdgeCasesTest::ProfileEntity }
                 ]
               }]
          get "oneof-mixed-as" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
      end

      def test_one_of_with_all_as_keys
        api_class = Class.new(Grape::API) do
          format :json
          desc "OneOf all with as",
               success: [{
                 one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity, as: "Model1" },
                   { model: ResponseEdgeCasesTest::ProfileEntity, as: "Model2" }
                 ]
               }]
          get "oneof-all-as" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
      end

      def test_one_of_mixed_with_regular_as
        api_class = Class.new(Grape::API) do
          format :json
          desc "OneOf mixed with regular as",
               success: [
                 { one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity },
                   { model: ResponseEdgeCasesTest::ProfileEntity }
                 ] },
                 { model: ResponseEdgeCasesTest::ItemEntity, as: "Model3" }
               ]
          get "oneof-mixed-regular-as" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_equal "object", schema.type
        assert_nil schema.one_of
        assert_includes schema.properties.keys, "Model3"
      end

      def test_multiple_one_of_blocks
        api_class = Class.new(Grape::API) do
          format :json
          desc "Multiple oneOf blocks",
               success: [
                 { one_of: [{ model: ResponseEdgeCasesTest::UserEntity }] },
                 { one_of: [{ model: ResponseEdgeCasesTest::ProfileEntity }] }
               ]
          get "oneof-multiple-blocks" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
      end

      def test_one_of_with_is_array
        api_class = Class.new(Grape::API) do
          format :json
          desc "OneOf with arrays",
               success: [{
                 one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity, is_array: true },
                   { model: ResponseEdgeCasesTest::ProfileEntity }
                 ]
               }]
          get "oneof-with-arrays" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 2, schema.one_of.size
        assert_equal "array", schema.one_of[0].type
        assert_equal "object", schema.one_of[1].type
      end

      def test_one_of_requires_model_or_entity
        api_class = Class.new(Grape::API) do
          format :json
          desc "Invalid oneOf",
               success: [{
                 one_of: [
                   { is_array: true }
                 ]
               }]
          get "test-invalid-oneof" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)

        error = assert_raises(ArgumentError) { builder.build }
        assert_includes error.message, "one_of items must include :model or :entity"
      end

      def test_one_of_mixed_with_regular_spec
        api_class = Class.new(Grape::API) do
          format :json
          desc "OneOf mixed with regular spec",
               success: [
                 { one_of: [
                   { model: ResponseEdgeCasesTest::UserEntity },
                   { model: ResponseEdgeCasesTest::ProfileEntity }
                 ] },
                 { model: ResponseEdgeCasesTest::ItemEntity }
               ]
          get "test-mixed-oneof-regular" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_nil schema.type
        assert_equal 3, schema.one_of.size
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::UserEntity", schema.one_of[0].canonical_name
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::ProfileEntity", schema.one_of[1].canonical_name
        assert_equal "GrapeOAS::ApiModelBuilders::ResponseEdgeCasesTest::ItemEntity", schema.one_of[2].canonical_name
      end

      def test_multiple_present_response_with_is_array
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user with items",
               success: [
                 { model: ResponseEdgeCasesTest::UserEntity, as: :user },
                 { model: ResponseEdgeCasesTest::ItemEntity, as: :items, is_array: true }
               ]
          get "users/:id/with-items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_equal "object", schema.type

        # user should be a direct entity reference
        user_schema = schema.properties["user"]

        refute_nil user_schema

        # items should be an array
        items_schema = schema.properties["items"]

        assert_equal "array", items_schema.type
        refute_nil items_schema.items
      end

      def test_multiple_present_response_with_required
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user with items",
               success: [
                 { model: ResponseEdgeCasesTest::UserEntity, as: :user, required: true },
                 { model: ResponseEdgeCasesTest::ItemEntity, as: :items, is_array: true }
               ]
          get "users/:id/required" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        response = responses.first
        schema = response.media_types.first.schema

        assert_equal ["user"], schema.required
      end

      def test_multiple_present_response_merges_same_status
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get combined data",
               success: [
                 { code: 200, model: ResponseEdgeCasesTest::UserEntity, as: :user },
                 { code: 200, model: ResponseEdgeCasesTest::ProfileEntity, as: :profile },
                 { code: 200, model: ResponseEdgeCasesTest::ItemEntity, as: :items, is_array: true, required: true }
               ]
          get "combined" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        # Should merge into a single response
        assert_equal 1, responses.size

        response = responses.first
        schema = response.media_types.first.schema

        assert_equal "object", schema.type
        assert_equal 3, schema.properties.size
        assert_includes schema.properties.keys, "user"
        assert_includes schema.properties.keys, "profile"
        assert_includes schema.properties.keys, "items"
        assert_equal ["items"], schema.required
      end
    end
  end
end
