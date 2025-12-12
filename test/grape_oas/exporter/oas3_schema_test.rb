# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3SchemaTest < Minitest::Test
      # === Zero value constraint tests ===

      def test_integer_schema_with_zero_minimum
        schema = ApiModel::Schema.new(type: "integer")
        schema.minimum = 0
        schema.maximum = 100

        result = OAS3::Schema.new(schema).build

        assert_equal 0, result["minimum"]
        assert_equal 100, result["maximum"]
      end

      def test_string_schema_with_zero_min_length
        schema = ApiModel::Schema.new(type: "string")
        schema.min_length = 0
        schema.max_length = 100

        result = OAS3::Schema.new(schema).build

        assert_equal 0, result["minLength"]
        assert_equal 100, result["maxLength"]
      end

      def test_array_schema_with_zero_min_items
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        schema.min_items = 0
        schema.max_items = 10

        result = OAS3::Schema.new(schema).build

        assert_equal 0, result["minItems"]
        assert_equal 10, result["maxItems"]
      end

      def test_constraints_not_included_when_not_set
        schema = ApiModel::Schema.new(type: "string")

        result = OAS3::Schema.new(schema).build

        refute result.key?("minimum")
        refute result.key?("maximum")
        refute result.key?("minLength")
        refute result.key?("maxLength")
        refute result.key?("pattern")
        refute result.key?("enum")
        refute result.key?("minItems")
        refute result.key?("maxItems")
        refute result.key?("exclusiveMinimum")
        refute result.key?("exclusiveMaximum")
      end

      # === Exclusive bounds tests ===

      def test_integer_schema_with_exclusive_bounds
        schema = ApiModel::Schema.new(type: "integer")
        schema.minimum = 0
        schema.exclusive_minimum = true
        schema.maximum = 100
        schema.exclusive_maximum = true

        result = OAS3::Schema.new(schema).build

        assert_equal 0, result["minimum"]
        assert result["exclusiveMinimum"]
        assert_equal 100, result["maximum"]
        assert result["exclusiveMaximum"]
      end

      # === Enum normalization tests ===

      def test_integer_schema_enum_normalized_from_strings
        schema = ApiModel::Schema.new(type: "integer")
        schema.enum = %w[1 2 3]

        result = OAS3::Schema.new(schema).build

        assert_equal [1, 2, 3], result["enum"]
      end

      def test_number_schema_enum_normalized_from_strings
        schema = ApiModel::Schema.new(type: "number")
        schema.enum = %w[1.5 2.5 3.5]

        result = OAS3::Schema.new(schema).build

        assert_equal [1.5, 2.5, 3.5], result["enum"]
      end
    end
  end
end
