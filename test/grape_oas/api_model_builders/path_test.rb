# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class PathTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_builds_path_from_simple_route
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            { users: [] }
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        assert_equal 1, @api.paths.size
        path = @api.paths.first

        assert_equal "/users", path.template
      end

      def test_sanitizes_path_parameters
        api_class = Class.new(Grape::API) do
          format :json
          get "users/:id" do
            { id: params[:id] }
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/users/{id}", path.template
      end

      def test_removes_json_format_extension
        api_class = Class.new(Grape::API) do
          get "users(.json)" do
            { users: [] }
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/users", path.template
      end

      def test_groups_operations_by_path
        api_class = Class.new(Grape::API) do
          format :json
          resource :users do
            get do
              { users: [] }
            end
            post do
              { user: {} }
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        assert_equal 1, @api.paths.size
        path = @api.paths.first

        assert_equal 2, path.operations.size
        methods = path.operations.map(&:http_method)

        assert_includes methods, "get"
        assert_includes methods, "post"
      end

      def test_skips_hidden_routes
        api_class = Class.new(Grape::API) do
          format :json
          get "visible" do
            {}
          end
          get "hidden", swagger: { hidden: true } do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        assert_equal 1, @api.paths.size
        path = @api.paths.first

        assert_equal "/visible", path.template
      end

      def test_handles_nested_path_parameters
        api_class = Class.new(Grape::API) do
          format :json
          get "users/:user_id/posts/:post_id" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/users/{user_id}/posts/{post_id}", path.template
      end
    end
  end
end
