# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for Path builder edge cases including hidden endpoints, mounted APIs, namespaces
    class PathEdgeCasesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Hidden endpoint via swagger option ===

      def test_hidden_endpoint_via_swagger_option
        api_class = Class.new(Grape::API) do
          format :json

          desc "Visible endpoint"
          get "visible" do
            {}
          end

          desc "Hidden endpoint", swagger: { hidden: true }
          get "hidden" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert(paths.any? { |p| p.include?("visible") })
        refute paths.any? { |p| p.include?("hidden") }, "Hidden endpoint should be filtered out"
      end

      def test_hidden_endpoint_via_desc_option
        api_class = Class.new(Grape::API) do
          format :json

          desc "Visible endpoint"
          get "visible" do
            {}
          end

          desc "Hidden endpoint", hidden: true
          get "hidden" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert(paths.any? { |p| p.include?("visible") })
        refute paths.any? { |p| p.include?("hidden") }, "Hidden via desc option should be filtered out"
      end

      def test_hidden_endpoint_via_verb_option
        api_class = Class.new(Grape::API) do
          format :json

          get "visible" do
            {}
          end

          get "hidden", hidden: true do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert(paths.any? { |p| p.include?("visible") })
        refute paths.any? { |p| p.include?("hidden") }, "Hidden via verb option should be filtered out"
      end

      def test_hidden_endpoint_with_lambda_true
        api_class = Class.new(Grape::API) do
          format :json

          desc "Visible endpoint"
          get "visible" do
            {}
          end

          desc "Conditionally hidden", hidden: -> { true }
          get "hidden" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert(paths.any? { |p| p.include?("visible") })
        refute paths.any? { |p| p.include?("hidden") }, "Lambda returning true should hide endpoint"
      end

      def test_hidden_endpoint_with_lambda_false
        api_class = Class.new(Grape::API) do
          format :json

          desc "Conditionally visible", hidden: -> { false }
          get "conditional" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert(paths.any? { |p| p.include?("conditional") }, "Lambda returning false should show endpoint")
      end

      def test_desc_hidden_overrides_swagger_setting
        api_class = Class.new(Grape::API) do
          format :json

          route_setting :swagger, hidden: false
          desc "This should be hidden", hidden: true
          get "hidden" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        refute paths.any? { |p| p.include?("hidden") }, "desc hidden should override swagger setting"
      end

      # === Multiple mounted APIs ===

      def test_mounted_apis_routes_collected
        inner_api = Class.new(Grape::API) do
          format :json
          get "inner" do
            {}
          end
        end

        outer_api = Class.new(Grape::API) do
          format :json
          mount inner_api
          get "outer" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: outer_api.routes, app: outer_api)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("inner") }, "Inner API route should be included"
        assert paths.any? { |p| p.include?("outer") }, "Outer API route should be included"
      end

      # === Namespace handling ===

      def test_namespace_routes_collected
        api_class = Class.new(Grape::API) do
          format :json

          namespace :users do
            get "/" do
              []
            end

            get "/:id" do
              {}
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("users") }, "Namespace route should be included"
      end

      # === Version in path ===

      def test_version_in_path
        api_class = Class.new(Grape::API) do
          format :json
          version "v1", using: :path

          get "items" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("/v1/") }, "Concrete version should be substituted into path"
        refute paths.any? { |p| p.include?("{version}") }, "Literal {version} placeholder should not remain"
      end

      # === Prefix handling ===

      def test_prefix_in_path
        api_class = Class.new(Grape::API) do
          format :json
          prefix :api

          get "items" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("api") }, "Prefix should be in path"
      end

      # === Route param handling ===

      def test_route_param_in_path
        api_class = Class.new(Grape::API) do
          format :json

          route_param :user_id do
            get "profile" do
              {}
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("{user_id}") }, "Route param should be in path with OpenAPI format"
      end

      # === Path parameter normalization ===

      def test_path_parameter_converted_to_openapi_format
        api_class = Class.new(Grape::API) do
          format :json

          get ":id" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        # :id should be converted to {id}
        assert paths.any? { |p| p.include?("{id}") }, "Path param should be converted to {id}"
        refute paths.any? { |p| p.include?(":id") }, "Colon format should not be present"
      end

      # === Format extension removal ===

      def test_format_extension_removed
        api_class = Class.new(Grape::API) do
          format :json

          get "items" do
            []
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        refute paths.any? { |p| p.include?("(.:format)") }, "Format extension should be removed"
        refute paths.any? { |p| p.include?("(.json)") }, "JSON extension should be removed"
      end

      # === Nested namespaces ===

      def test_nested_namespaces
        api_class = Class.new(Grape::API) do
          format :json

          namespace :v1 do
            namespace :users do
              namespace :posts do
                get "/" do
                  []
                end
              end
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert paths.any? { |p| p.include?("v1") && p.include?("users") && p.include?("posts") },
               "Nested namespaces should all be in path"
      end

      # === Multiple path params ===

      def test_multiple_path_params
        api_class = Class.new(Grape::API) do
          format :json

          get ":org_id/teams/:team_id/members/:member_id" do
            {}
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)
        path = paths.first

        assert_includes path, "{org_id}", "org_id should be converted"
        assert_includes path, "{team_id}", "team_id should be converted"
        assert_includes path, "{member_id}", "member_id should be converted"
      end

      # === Group (resource) handling ===

      def test_resource_group_routes
        api_class = Class.new(Grape::API) do
          format :json

          resource :articles do
            get "/" do
              []
            end

            post "/" do
              {}
            end

            route_param :id do
              get do
                {}
              end

              put do
                {}
              end

              delete do
                {}
              end
            end
          end
        end

        builder = Path.new(api: @api, routes: api_class.routes, app: api_class)
        builder.build

        paths = @api.paths.map(&:template)

        assert_includes paths, "/articles", "Collection path should exist"
        assert_includes paths, "/articles/{id}", "Resource path should exist"
      end
    end
  end
end
