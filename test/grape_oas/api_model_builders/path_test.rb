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

      def test_substitutes_concrete_version_into_path
        api_class = Class.new(Grape::API) do
          format :json
          version "v1", using: :path
          get "items" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/v1/items", path.template
      end

      def test_preserves_version_placeholder_without_concrete_version
        api_class = Class.new(Grape::API) do
          format :json
          get "foo/:version" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/foo/{version}", path.template
      end

      def test_preserves_user_version_parameter_when_versioning_uses_header
        api_class = Class.new(Grape::API) do
          format :json
          version "v1", using: :header, vendor: "test"
          get "foo/:version" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/foo/{version}", path.template
      end

      def test_path_versioning_only_substitutes_grape_version_segment
        api_class = Class.new(Grape::API) do
          format :json
          version "v1", using: :path
          get "foo/:version" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/v1/foo/{version}", path.template
      end

      def test_concrete_version_preserves_format_extension_and_named_params
        api_class = Class.new(Grape::API) do
          version "v1", using: :path
          get "items/:id(.json)" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        path = @api.paths.first

        assert_equal "/v1/items/{id}", path.template
      end

      # === Namespace filtering tests ===

      def test_namespace_filter_includes_matching_paths
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
          get "users/:id" do
            {}
          end
          get "posts" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, namespace_filter: "users")
        builder.build

        templates = @api.paths.map(&:template)

        assert_equal 2, @api.paths.size
        assert_includes templates, "/users"
        assert_includes templates, "/users/{id}"
        refute_includes templates, "/posts"
      end

      def test_namespace_filter_with_leading_slash
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
          get "posts" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, namespace_filter: "/users")
        builder.build

        assert_equal 1, @api.paths.size
        assert_equal "/users", @api.paths.first.template
      end

      def test_namespace_filter_with_nested_paths
        api_class = Class.new(Grape::API) do
          format :json
          namespace :users do
            get do
              {}
            end
            get ":id" do
              {}
            end
            namespace :posts do
              get do
                {}
              end
            end
          end
          get "other" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, namespace_filter: "users")
        builder.build

        templates = @api.paths.map(&:template)

        assert_equal 3, @api.paths.size
        assert_includes templates, "/users"
        assert_includes templates, "/users/{id}"
        assert_includes templates, "/users/posts"
        refute_includes templates, "/other"
      end

      def test_namespace_filter_excludes_partial_matches
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
          get "users_admin" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, namespace_filter: "users")
        builder.build

        # Only /users should match, not /users_admin (partial match)
        assert_equal 1, @api.paths.size
        assert_equal "/users", @api.paths.first.template
      end

      def test_no_namespace_filter_includes_all_paths
        api_class = Class.new(Grape::API) do
          format :json
          get "users" do
            {}
          end
          get "posts" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes)
        builder.build

        assert_equal 2, @api.paths.size
      end

      def test_namespace_filter_with_nested_namespace
        api_class = Class.new(Grape::API) do
          format :json
          namespace :users do
            get do
              {}
            end
            namespace :posts do
              get do
                {}
              end
              get ":id" do
                {}
              end
            end
            namespace :comments do
              get do
                {}
              end
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, namespace_filter: "users/posts")
        builder.build

        templates = @api.paths.map(&:template)

        assert_equal 2, @api.paths.size
        assert_includes templates, "/users/posts"
        assert_includes templates, "/users/posts/{id}"
        refute_includes templates, "/users"
        refute_includes templates, "/users/comments"
      end
    end
  end
end
