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
        assert_equal false, enabled_param.schema.default # rubocop:disable Minitest/RefuteFalse
        assert_equal true, disabled_param.schema.default # rubocop:disable Minitest/AssertTruthy
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
        assert_equal 0, count_param.schema.default
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
        assert_equal "", prefix_param.schema.default
        assert_equal "default", suffix_param.schema.default
      end

      # === Array default ===

      def test_array_default_value
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :tags, type: [String], default: %w[default], documentation: { param_type: "body" }
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
        assert_equal %w[default], tags.default
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
        assert_nil nullable_param.schema.default
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
        assert_equal "pending", status_param.schema.default
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
        assert_equal 30, config.properties["timeout"].default
        assert_equal 3, config.properties["retries"].default
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
        # spec[:default] takes precedence over doc[:default]
        assert_equal "param_default", value_param.schema.default
      end

      # === Documentation-only default ===

      def test_documentation_only_default_applied
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :value, type: String, documentation: { default: "doc_default" }
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
        assert_equal "doc_default", value_param.schema.default
      end

      # === Callable default (lambda / proc) ===

      def test_callable_default_not_emitted
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :limit, type: Integer, default: -> { 25 }
            optional :token, type: String, default: proc { "generated" }
            optional :page_size, type: Integer, default: ->(params) { params[:page].to_i * 10 }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        # Grape evaluates callable defaults per request; the spec has no static value
        %w[limit token page_size].each do |name|
          param = params.find { |p| p.name == name }

          refute_nil param, name
          assert_nil param.schema.default, name
        end
      end

      def test_callable_default_not_called
        called = false
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :limit, type: Integer, default: -> { called = true }
          end
          get "items" do
            {}
          end
        end

        RequestParams.new(api: @api, route: api_class.routes.first).build

        refute called, "callable default must not run at generation time"
      end

      def test_callable_default_falls_back_to_documentation_default
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :since, type: Time, default: -> { Time.now }, documentation: { default: "now" }
          end
          get "events" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        since_param = params.find { |p| p.name == "since" }

        refute_nil since_param
        assert_equal "now", since_param.schema.default
      end

      def test_callable_default_absent_from_exported_spec
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :limit, type: Integer, default: -> { 25 }
          end
          get "items" do
            {}
          end
        end

        %i[oas2 oas3 oas31].each do |schema_type|
          spec = JSON.parse(JSON.generate(GrapeOAS.generate(app: api_class, schema_type: schema_type)))
          param = spec.dig("paths", "/items", "get", "parameters").find { |p| p["name"] == "limit" }

          refute_nil param, schema_type
          refute param.key?("default"), "#{schema_type} emits a default for a callable"
          refute param.fetch("schema", {}).key?("default"), "#{schema_type} emits a default for a callable"
        end
      end
    end
  end
end
