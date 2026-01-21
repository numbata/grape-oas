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

      # === Multi-type (oneOf) with enum ===

      def test_multi_type_with_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            # Use types: [String, NilClass] - optimized to nullable string (not oneOf)
            optional :status, types: [String, NilClass], values: %w[visible hidden]
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        status_param = params.find { |p| p.name == "status" }

        refute_nil status_param
        # [String, NilClass] is optimized to nullable string (not oneOf)
        assert_equal Constants::SchemaTypes::STRING, status_param.schema.type
        assert status_param.schema.nullable

        # The enum should be applied directly to the schema
        assert_equal %w[visible hidden], status_param.schema.enum
      end

      def test_multi_type_three_types_still_uses_one_of
        api_class = Class.new(Grape::API) do
          format :json
          params do
            # Three types: NilClass is filtered out and represented via nullable
            optional :value, types: [String, Integer, NilClass], values: %w[a b c]
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        value_param = params.find { |p| p.name == "value" }

        refute_nil value_param
        # NilClass is filtered out, represented via nullable property
        refute_nil value_param.schema.one_of
        assert_equal 2, value_param.schema.one_of.size
        assert value_param.schema.nullable

        # String variant should have the string enum
        string_variant = value_param.schema.one_of.find { |s| s.type == Constants::SchemaTypes::STRING }

        assert_equal %w[a b c], string_variant.enum

        # Integer variant should NOT have string enum (type incompatible)
        integer_variant = value_param.schema.one_of.find { |s| s.type == Constants::SchemaTypes::INTEGER }

        assert_nil integer_variant.enum
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
    end
  end
end
