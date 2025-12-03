# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for parameter enum/values handling
    class RequestParamsEnumTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Basic array values ===

      def test_string_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :status, type: String, values: %w[pending active completed]
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
        assert_equal %w[pending active completed], status_param.schema.enum
      end

      # === Symbol values ===

      def test_symbol_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :priority, type: Symbol, values: %i[low medium high]
          end
          get "issues" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        priority_param = params.find { |p| p.name == "priority" }

        refute_nil priority_param
        assert_equal "string", priority_param.schema.type # Symbol -> string
      end

      # === Integer values ===

      def test_integer_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :level, type: Integer, values: [1, 2, 3, 4, 5]
          end
          get "ratings" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        level_param = params.find { |p| p.name == "level" }

        refute_nil level_param
        assert_equal "integer", level_param.schema.type
      end

      # === Range values (integer) ===

      def test_integer_range_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :rating, type: Integer, values: 1..5
          end
          get "reviews" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        rating_param = params.find { |p| p.name == "rating" }

        refute_nil rating_param
        assert_equal "integer", rating_param.schema.type
        # Range converts to minimum/maximum constraints
        assert_equal 1, rating_param.schema.minimum
        assert_equal 5, rating_param.schema.maximum
      end

      # === Range values (negative) ===

      def test_negative_range_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :offset, type: Integer, values: -10..10
          end
          get "data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        offset_param = params.find { |p| p.name == "offset" }

        refute_nil offset_param
        assert_equal "integer", offset_param.schema.type
        assert_equal(-10, offset_param.schema.minimum)
        assert_equal 10, offset_param.schema.maximum
      end

      # === Float range values ===

      def test_float_range_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :temperature, type: Float, values: -40.0..50.0
          end
          get "weather" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        temp_param = params.find { |p| p.name == "temperature" }

        refute_nil temp_param
        assert_equal "number", temp_param.schema.type
        assert_in_delta(-40.0, temp_param.schema.minimum)
        assert_in_delta(50.0, temp_param.schema.maximum)
      end

      # === String range values ===

      def test_string_range_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :letter, type: String, values: "a".."e"
          end
          get "letters" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        letter_param = params.find { |p| p.name == "letter" }

        refute_nil letter_param
        assert_equal "string", letter_param.schema.type
        # String range expands to enum array
        assert_equal %w[a b c d e], letter_param.schema.enum
      end

      # === Proc values ===

      def test_proc_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :dynamic, type: String, values: proc { %w[a b c] }
          end
          get "dynamic" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        dynamic_param = params.find { |p| p.name == "dynamic" }

        refute_nil dynamic_param
        assert_equal "string", dynamic_param.schema.type
        # Proc is evaluated and result is used as enum
        assert_equal %w[a b c], dynamic_param.schema.enum
      end

      # === Empty values array ===

      def test_empty_values_array
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :field, type: String, values: []
          end
          get "empty" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        field_param = params.find { |p| p.name == "field" }

        refute_nil field_param
      end

      # === Single value enum ===

      def test_single_value_enum
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :constant, type: String, values: ["fixed"]
          end
          get "constant" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        constant_param = params.find { |p| p.name == "constant" }

        refute_nil constant_param
      end

      # === Values in nested hash ===

      def test_values_in_nested_hash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :filter, type: Hash do
              requires :status, type: String, values: %w[active inactive]
              optional :sort, type: String, values: %w[asc desc], default: "asc"
            end
          end
          post "search" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        filter = body_schema.properties["filter"]

        refute_nil filter
        assert_includes filter.properties.keys, "status"
        assert_includes filter.properties.keys, "sort"
      end
    end
  end
end
