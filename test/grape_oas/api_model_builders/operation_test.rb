# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class OperationTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_extracts_http_method
        api_class = Class.new(Grape::API) do
          format :json
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_equal "post", operation.http_method
      end

      def test_extracts_summary_from_description
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get all users"
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_equal "Get all users", operation.summary
      end

      def test_uses_nickname_for_operation_id
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user", nickname: "getUserById"
          get "users/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_equal "getUserById", operation.operation_id
      end

      def test_generates_operation_id_from_path_when_no_nickname
        api_class = Class.new(Grape::API) do
          format :json
          get "users/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_match(/^get_/, operation.operation_id)
      end

      def test_extracts_tags
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get users", tags: %w[users admin]
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_equal %w[users admin], operation.tag_names
      end

      def test_adds_tags_to_api
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get users", tags: ["users"]
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        builder.build

        assert_includes @api.tag_defs, "users"
      end

      def test_builds_response
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert_equal 1, operation.responses.size
        response = operation.responses.first

        assert_equal "200", response.http_status
      end

      def test_builds_parameters
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
        builder = Operation.new(api: @api, route: route)
        operation = builder.build

        assert(operation.parameters.any? { |p| p.name == "id" })
      end
    end
  end
end
