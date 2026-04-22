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

      # === Set values (Grape internally stores values: as Set) ===

      def test_set_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :sort_order, type: Symbol, values: Set[:asc, :desc]
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        sort_param = params.find { |p| p.name == "sort_order" }

        refute_nil sort_param
        assert_equal "string", sort_param.schema.type
        assert_includes sort_param.schema.enum, :asc
        assert_includes sort_param.schema.enum, :desc
        assert_equal 2, sort_param.schema.enum.size
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

      # === BigDecimal range values ===

      def test_bigdecimal_range_values
        require "bigdecimal"
        require "bigdecimal/util"

        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :discount_rate,
                     type: BigDecimal,
                     values: BigDecimal(0)..BigDecimal(1),
                     desc: "Discount rate applied to the order",
                     documentation: { example: 0.25 }
          end
          get "orders" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        discount_param = params.find { |p| p.name == "discount_rate" }

        refute_nil discount_param
        refute discount_param.required
        assert_equal "number", discount_param.schema.type
        assert_equal "double", discount_param.schema.format
        assert_equal "Discount rate applied to the order", discount_param.description
        assert_in_delta 0.25, discount_param.schema.examples
        # Bounds are coerced to Float so they serialize as JSON numbers, not
        # strings (BigDecimal#to_json emits "0.1e1" etc.).
        assert_in_delta 0.0, discount_param.schema.minimum
        assert_in_delta 1.0, discount_param.schema.maximum
        assert_kind_of Float, discount_param.schema.minimum
        assert_kind_of Float, discount_param.schema.maximum
        refute discount_param.schema.exclusive_maximum
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

      # === Range values on container schemas ===

      def test_integer_range_values_on_array_param
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :ids, type: [Integer], values: 1..100, documentation: { param_type: "body" }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        ids = body_schema.properties["ids"]

        refute_nil ids
        assert_equal Constants::SchemaTypes::ARRAY, ids.type
        assert_equal 1, ids.items.minimum
        assert_equal 100, ids.items.maximum
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
        assert_nil field_param.schema.enum
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
        assert_equal ["fixed"], constant_param.schema.enum
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

      # === [false] enum regression ===

      def test_false_only_enum_applied_to_schema
        # [false].any? returns false in Ruby, which previously caused [false] to be
        # silently dropped. Verify SchemaEnhancer.apply correctly sets enum: [false].
        enhancer = RequestParamsSupport::SchemaEnhancer
        schema = ApiModel::Schema.new(type: Constants::SchemaTypes::BOOLEAN)

        enhancer.apply(schema, { values: [false] }, {})

        assert_equal [false], schema.enum
      end

      # === Mixed-type enum values (unit tests for filter_compatible_values) ===

      def test_filter_compatible_values_splits_mixed_enum
        # Unit test for SchemaEnhancer.filter_compatible_values
        # Grape DSL doesn't allow mixed-type enums, but we test the filter logic directly
        enhancer = RequestParamsSupport::SchemaEnhancer

        string_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        integer_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
        mixed_values = ["a", "b", 1, 2]

        # String schema should filter to only strings
        string_result = enhancer.send(:filter_compatible_values, string_schema, mixed_values)

        assert_equal %w[a b], string_result

        # Integer schema should filter to only integers
        integer_result = enhancer.send(:filter_compatible_values, integer_schema, mixed_values)

        assert_equal [1, 2], integer_result
      end

      def test_filter_compatible_values_returns_all_for_homogeneous_enum
        enhancer = RequestParamsSupport::SchemaEnhancer

        string_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        string_values = %w[a b c]

        result = enhancer.send(:filter_compatible_values, string_schema, string_values)

        assert_equal %w[a b c], result
      end

      def test_filter_compatible_values_returns_empty_for_incompatible_enum
        enhancer = RequestParamsSupport::SchemaEnhancer

        integer_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
        string_values = %w[a b c]

        result = enhancer.send(:filter_compatible_values, integer_schema, string_values)

        assert_empty result
      end

      # === SchemaEnhancer edge cases for range and callable handling ===

      def test_exclusive_range_sets_exclusive_maximum
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :score, type: Integer, values: 0...10
          end
          get "scores" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        score_param = params.find { |p| p.name == "score" }

        assert_equal 0, score_param.schema.minimum
        assert_equal 10, score_param.schema.maximum
        assert score_param.schema.exclusive_maximum
      end

      def test_descending_numeric_range_is_skipped
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :level, type: Integer, values: 10..1
          end
          get "levels" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        level_param = params.find { |p| p.name == "level" }

        assert_nil level_param.schema.minimum
        assert_nil level_param.schema.maximum
      end

      def test_raising_proc_does_not_crash
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :status, type: String, values: proc { raise ArgumentError, "boom" }
          end
          get "statuses" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)

        log = capture_grape_oas_log do
          _body_schema, params = builder.build
          status_param = params.find { |p| p.name == "status" }

          assert_nil status_param.schema.enum
        end

        assert_match(/Proc evaluation failed/, log)
      end

      def test_wide_string_range_is_capped
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :code, type: String, values: "a".."zzzzzz"
          end
          get "codes" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        code_param = params.find { |p| p.name == "code" }

        assert_nil code_param.schema.enum
      end
    end
  end
end
