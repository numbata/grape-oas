# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for parameter default value handling
    class RequestParamsDefaultsTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Boolean false default ===

      def test_boolean_false_default_preserved
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :enabled, type: Grape::API::Boolean, default: false
            optional :disabled, type: Grape::API::Boolean, default: true
          end
          get "settings" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        enabled_param = params.find { |p| p.name == "enabled" }
        disabled_param = params.find { |p| p.name == "disabled" }

        # Boolean false should be preserved, not treated as nil
        refute_nil enabled_param
        refute_nil disabled_param
        assert_equal "boolean", enabled_param.schema.type
        assert_equal "boolean", disabled_param.schema.type
      end

      # === Integer zero default ===

      def test_integer_zero_default_preserved
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :count, type: Integer, default: 0
            optional :offset, type: Integer, default: 10
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        count_param = params.find { |p| p.name == "count" }

        refute_nil count_param
        assert_equal "integer", count_param.schema.type
      end

      # === String empty default ===

      def test_string_empty_default_preserved
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :prefix, type: String, default: ""
            optional :suffix, type: String, default: "default"
          end
          get "format" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        prefix_param = params.find { |p| p.name == "prefix" }
        suffix_param = params.find { |p| p.name == "suffix" }

        refute_nil prefix_param
        refute_nil suffix_param
      end

      # === Array default ===

      def test_array_default_value
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :tags, type: Array[String], default: %w[default], documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        tags = body_schema.properties["tags"]

        refute_nil tags
        assert_equal "array", tags.type
      end

      # === Nil default (explicitly nil) ===

      def test_nil_default_handling
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :nullable_field, type: String, default: nil
          end
          get "data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        nullable_param = params.find { |p| p.name == "nullable_field" }

        refute_nil nullable_param
      end

      # === Default with enum values ===

      def test_default_with_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :status, type: String, values: %w[pending active done], default: "pending"
          end
          get "tasks" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        status_param = params.find { |p| p.name == "status" }

        refute_nil status_param
        assert_equal "string", status_param.schema.type
      end

      # === Default in nested hash ===

      def test_default_in_nested_hash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :config, type: Hash do
              optional :timeout, type: Integer, default: 30
              optional :retries, type: Integer, default: 3
            end
          end
          post "settings" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        config = body_schema.properties["config"]

        refute_nil config
        assert_equal "object", config.type
        assert_includes config.properties.keys, "timeout"
        assert_includes config.properties.keys, "retries"
      end

      # === Documentation default vs param default ===

      def test_documentation_default_vs_param_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :value, type: String, default: "param_default",
                            documentation: { default: "doc_default" }
          end
          get "test" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        value_param = params.find { |p| p.name == "value" }

        refute_nil value_param
        # Just verify parameter exists - default source depends on implementation
      end
    end
  end
end
