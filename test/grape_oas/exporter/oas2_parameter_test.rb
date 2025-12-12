# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2ParameterTest < Minitest::Test
      def test_collection_format_multi_for_array_param
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "statuses",
          schema: schema,
          required: false,
          collection_format: "multi",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        statuses_param = result.find { |p| p["name"] == "statuses" }

        assert_equal "multi", statuses_param["collectionFormat"]
      end

      def test_collection_format_csv_for_array_param
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "integer"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "ids",
          schema: schema,
          required: false,
          collection_format: "csv",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        ids_param = result.find { |p| p["name"] == "ids" }

        assert_equal "csv", ids_param["collectionFormat"]
      end

      def test_collection_format_brackets
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "tags",
          schema: schema,
          required: false,
          collection_format: "brackets",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        tags_param = result.find { |p| p["name"] == "tags" }

        assert_equal "brackets", tags_param["collectionFormat"]
      end

      def test_invalid_collection_format_ignored
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "items",
          schema: schema,
          required: false,
          collection_format: "invalid",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        items_param = result.find { |p| p["name"] == "items" }

        refute items_param.key?("collectionFormat")
      end

      def test_no_collection_format_for_non_array
        schema = ApiModel::Schema.new(type: "string")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "name",
          schema: schema,
          required: false,
          collection_format: "multi",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        name_param = result.find { |p| p["name"] == "name" }

        refute name_param.key?("collectionFormat")
      end

      def test_no_collection_format_when_nil
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "values",
          schema: schema,
          required: false,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        values_param = result.find { |p| p["name"] == "values" }

        refute values_param.key?("collectionFormat")
      end

      def test_integer_parameter_includes_minimum_and_maximum
        schema = ApiModel::Schema.new(type: "integer")
        schema.minimum = 1
        schema.maximum = 50
        param = ApiModel::Parameter.new(
          location: "query",
          name: "count",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        count_param = result.find { |p| p["name"] == "count" }

        assert_equal 1, count_param["minimum"]
        assert_equal 50, count_param["maximum"]
      end

      def test_string_parameter_includes_enum
        schema = ApiModel::Schema.new(type: "string")
        schema.enum = %w[small medium large]
        param = ApiModel::Parameter.new(
          location: "query",
          name: "size",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        size_param = result.find { |p| p["name"] == "size" }

        assert_equal %w[small medium large], size_param["enum"]
      end

      def test_string_parameter_includes_min_max_length
        schema = ApiModel::Schema.new(type: "string")
        schema.min_length = 3
        schema.max_length = 100
        param = ApiModel::Parameter.new(
          location: "query",
          name: "name",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        name_param = result.find { |p| p["name"] == "name" }

        assert_equal 3, name_param["minLength"]
        assert_equal 100, name_param["maxLength"]
      end

      def test_string_parameter_includes_pattern
        schema = ApiModel::Schema.new(type: "string")
        schema.pattern = "^[A-Z]{2}[0-9]{4}$"
        param = ApiModel::Parameter.new(
          location: "query",
          name: "code",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        code_param = result.find { |p| p["name"] == "code" }

        assert_equal "^[A-Z]{2}[0-9]{4}$", code_param["pattern"]
      end

      def test_integer_parameter_with_zero_minimum
        schema = ApiModel::Schema.new(type: "integer")
        schema.minimum = 0
        schema.maximum = 100
        param = ApiModel::Parameter.new(
          location: "query",
          name: "count",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        count_param = result.find { |p| p["name"] == "count" }

        assert_equal 0, count_param["minimum"]
        assert_equal 100, count_param["maximum"]
      end

      def test_string_parameter_with_zero_min_length
        schema = ApiModel::Schema.new(type: "string")
        schema.min_length = 0
        schema.max_length = 100
        param = ApiModel::Parameter.new(
          location: "query",
          name: "optional_text",
          schema: schema,
          required: false,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        text_param = result.find { |p| p["name"] == "optional_text" }

        assert_equal 0, text_param["minLength"]
        assert_equal 100, text_param["maxLength"]
      end

      def test_integer_parameter_with_exclusive_bounds
        schema = ApiModel::Schema.new(type: "integer")
        schema.minimum = 0
        schema.exclusive_minimum = true
        schema.maximum = 100
        schema.exclusive_maximum = true
        param = ApiModel::Parameter.new(
          location: "query",
          name: "value",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        value_param = result.find { |p| p["name"] == "value" }

        assert_equal 0, value_param["minimum"]
        assert value_param["exclusiveMinimum"]
        assert_equal 100, value_param["maximum"]
        assert value_param["exclusiveMaximum"]
      end

      def test_array_parameter_with_min_max_items
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        schema.min_items = 1
        schema.max_items = 10
        param = ApiModel::Parameter.new(
          location: "query",
          name: "tags",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        tags_param = result.find { |p| p["name"] == "tags" }

        assert_equal 1, tags_param["minItems"]
        assert_equal 10, tags_param["maxItems"]
      end

      def test_constraints_not_included_when_not_set
        schema = ApiModel::Schema.new(type: "string")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "simple",
          schema: schema,
          required: false,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        simple_param = result.find { |p| p["name"] == "simple" }

        refute simple_param.key?("minimum")
        refute simple_param.key?("maximum")
        refute simple_param.key?("minLength")
        refute simple_param.key?("maxLength")
        refute simple_param.key?("pattern")
        refute simple_param.key?("enum")
        refute simple_param.key?("minItems")
        refute simple_param.key?("maxItems")
        refute simple_param.key?("exclusiveMinimum")
        refute simple_param.key?("exclusiveMaximum")
      end

      def test_integer_parameter_enum_normalized_from_strings
        schema = ApiModel::Schema.new(type: "integer")
        schema.enum = %w[1 2 3]
        param = ApiModel::Parameter.new(
          location: "query",
          name: "priority",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        priority_param = result.find { |p| p["name"] == "priority" }

        assert_equal [1, 2, 3], priority_param["enum"]
      end

      def test_number_parameter_enum_normalized_from_strings
        schema = ApiModel::Schema.new(type: "number")
        schema.enum = %w[1.5 2.5 3.5]
        param = ApiModel::Parameter.new(
          location: "query",
          name: "rate",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        rate_param = result.find { |p| p["name"] == "rate" }

        assert_equal [1.5, 2.5, 3.5], rate_param["enum"]
      end

      def test_integer_parameter_enum_removes_duplicates
        schema = ApiModel::Schema.new(type: "integer")
        schema.enum = %w[1 2 2 3 3 3]
        param = ApiModel::Parameter.new(
          location: "query",
          name: "level",
          schema: schema,
          required: true,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        level_param = result.find { |p| p["name"] == "level" }

        assert_equal [1, 2, 3], level_param["enum"]
      end
    end
  end
end
