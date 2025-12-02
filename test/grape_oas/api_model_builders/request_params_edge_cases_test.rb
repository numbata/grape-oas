# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsEdgeCasesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Array parameters with enum values (grape-swagger #650) ===

      def test_array_param_with_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :statuses, type: [String], values: %w[pending active completed],
                                documentation: { param_type: "body" }
          end
          post "tasks" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        statuses = body_schema.properties["statuses"]

        assert_equal "array", statuses.type
        # NOTE: enum should be on items, not on the array itself
        # This tests if we properly handle this edge case
      end

      def test_array_param_with_default_value
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :tags, type: [String], default: %w[default],
                            documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        tags = body_schema.properties["tags"]

        assert_equal "array", tags.type
        # Default values handling
      end

      # === Deeply nested objects (grape-swagger #751, #832) ===

      def test_four_level_deep_nesting
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :level1, type: Hash do
              requires :level2, type: Hash do
                requires :level3, type: Hash do
                  requires :level4, type: Hash do
                    requires :value, type: String
                  end
                end
              end
            end
          end
          post "deep" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        # Navigate through all levels
        level1 = body_schema.properties["level1"]

        assert_equal "object", level1.type

        level2 = level1.properties["level2"]

        assert_equal "object", level2.type

        level3 = level2.properties["level3"]

        assert_equal "object", level3.type

        level4 = level3.properties["level4"]

        assert_equal "object", level4.type
        assert_includes level4.properties.keys, "value"
        assert_equal "string", level4.properties["value"].type
      end

      def test_nested_array_in_hash_in_array
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :items, type: Array do
              requires :name, type: String
              requires :options, type: Hash do
                requires :values, type: Array do
                  requires :key, type: String
                  requires :score, type: Integer
                end
              end
            end
          end
          post "complex" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        items = body_schema.properties["items"]

        assert_equal "array", items.type

        item_schema = items.items

        assert_equal "object", item_schema.type
        assert_includes item_schema.properties.keys, "name"
        assert_includes item_schema.properties.keys, "options"

        options = item_schema.properties["options"]

        assert_equal "object", options.type

        values = options.properties["values"]

        assert_equal "array", values.type
        assert_includes values.items.properties.keys, "key"
        assert_includes values.items.properties.keys, "score"
      end

      # === Mixed types with Float and BigDecimal (grape-swagger #832) ===

      def test_nested_float_and_bigdecimal_types
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :measurements, type: Hash do
              requires :temperature, type: Float
              requires :precision, type: BigDecimal
              optional :readings, type: Array do
                requires :value, type: Float
                requires :weight, type: BigDecimal
              end
            end
          end
          post "data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        measurements = body_schema.properties["measurements"]

        assert_equal "number", measurements.properties["temperature"].type
        assert_equal "number", measurements.properties["precision"].type

        readings = measurements.properties["readings"]

        assert_equal "array", readings.type
        assert_equal "number", readings.items.properties["value"].type
        assert_equal "number", readings.items.properties["weight"].type
      end

      # === Route parameters with explicit types (grape-swagger #847) ===

      def test_route_param_with_explicit_type
        api_class = Class.new(Grape::API) do
          format :json
          route_param :account_number, type: String do
            params do
              requires :amount, type: Float, documentation: { param_type: "body" }
            end
            put "transfer" do
              {}
            end
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, params = builder.build

        # account_number should be a path param with String type
        account_param = params.find { |p| p.name == "account_number" }

        assert_equal "path", account_param&.location
        assert_equal "string", account_param&.schema&.type

        # amount should be in body
        assert_includes body_schema.properties.keys, "amount"
      end

      # === Multiple path parameters (grape-swagger #587) ===

      def test_multiple_path_params_in_route
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :start_date, type: String, desc: "Start date"
            requires :end_date, type: String, desc: "End date"
          end
          get "range/:start_date/:end_date" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        start_param = params.find { |p| p.name == "start_date" }
        end_param = params.find { |p| p.name == "end_date" }

        assert_equal "path", start_param.location
        assert_equal "path", end_param.location
      end

      # === Optional nested hash (partial structure) ===

      def test_optional_nested_hash_with_some_required_children
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String
            optional :preferences, type: Hash do
              requires :theme, type: String
              optional :language, type: String
              optional :notifications, type: Hash do
                requires :email, type: Grape::API::Boolean
                optional :sms, type: Grape::API::Boolean
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

        assert_includes body_schema.required, "name"
        refute_includes body_schema.required, "preferences"

        prefs = body_schema.properties["preferences"]

        assert_includes prefs.required, "theme"
        refute_includes prefs.required, "language"
        refute_includes prefs.required, "notifications"

        notifs = prefs.properties["notifications"]

        assert_includes notifs.required, "email"
        refute_includes notifs.required, "sms"
      end

      # === Boolean types (TrueClass/FalseClass and Grape::API::Boolean) ===

      def test_boolean_type_variations
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :active, type: Grape::API::Boolean
            optional :verified, type: TrueClass
            optional :deleted, type: FalseClass
          end
          get "status" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        active_param = params.find { |p| p.name == "active" }
        verified_param = params.find { |p| p.name == "verified" }
        deleted_param = params.find { |p| p.name == "deleted" }

        assert_equal "boolean", active_param.schema.type
        assert_equal "boolean", verified_param.schema.type
        assert_equal "boolean", deleted_param.schema.type
      end

      # === Symbol type fallback ===

      def test_symbol_type_falls_back_to_string
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :status, type: Symbol
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        status_param = params.find { |p| p.name == "status" }

        assert_equal "string", status_param.schema.type
      end

      # === Array without items (edge case) ===

      def test_plain_array_type_without_member_specification
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :data, type: Array, documentation: { param_type: "body" }
          end
          post "import" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        data = body_schema.properties["data"]

        assert_equal "array", data.type
        refute_nil data.items, "Plain Array should have items schema"
        assert_equal "string", data.items.type, "Default items type should be string"
      end
    end
  end
end
