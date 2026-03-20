# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class RangeUtilsTest < Minitest::Test
    def test_expands_string_range
      assert_equal %w[a b c d e], RangeUtils.expand_range_to_enum("a".."e")
    end

    def test_expands_single_element_range
      assert_equal %w[x], RangeUtils.expand_range_to_enum("x".."x")
    end

    def test_returns_nil_for_numeric_range
      assert_nil RangeUtils.expand_range_to_enum(1..10)
    end

    def test_returns_nil_for_float_range
      assert_nil RangeUtils.expand_range_to_enum(1.0..10.0)
    end

    def test_returns_nil_for_endless_range
      assert_nil RangeUtils.expand_range_to_enum("a"..)
    end

    def test_returns_nil_for_beginless_range
      assert_nil RangeUtils.expand_range_to_enum(.."z")
    end

    def test_returns_nil_for_empty_descending_range
      assert_nil RangeUtils.expand_range_to_enum("z".."a")
    end

    def test_returns_nil_for_wide_range_exceeding_limit
      assert_nil RangeUtils.expand_range_to_enum("a".."zzzzzz")
    end

    def test_returns_nil_for_non_discrete_range
      assert_nil RangeUtils.expand_range_to_enum(Time.new(2024, 1, 1)..Time.new(2024, 12, 31))
    end

    def test_expands_range_at_exactly_max_size
      # Build a string range of exactly MAX_ENUM_RANGE_SIZE (100) elements: "a".."cv"
      all_elements = ("a".."zz").to_a
      range_end = all_elements[Constants::MAX_ENUM_RANGE_SIZE - 1]
      range = "a"..range_end
      result = RangeUtils.expand_range_to_enum(range)

      refute_nil result
      assert_equal Constants::MAX_ENUM_RANGE_SIZE, result.length
    end

    def test_returns_nil_for_range_exceeding_max_by_one
      # 'a'..'zz' produces 702 elements which exceeds MAX_ENUM_RANGE_SIZE (100)
      assert_nil RangeUtils.expand_range_to_enum("a".."zz")
    end

    def test_handles_exclusive_string_range
      assert_equal %w[a b c d], RangeUtils.expand_range_to_enum("a"..."e")
    end

    # === apply_to_schema tests ===

    def test_apply_numeric_range_to_integer_schema
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 1..10)

      assert_equal 1, schema.minimum
      assert_equal 10, schema.maximum
      assert_nil schema.exclusive_maximum
    end

    def test_apply_exclusive_range_sets_exclusive_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 0...10)

      assert_equal 0, schema.minimum
      assert_equal 10, schema.maximum
      assert schema.exclusive_maximum
    end

    def test_apply_descending_numeric_range_is_skipped
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 10..1)

      assert_nil schema.minimum
      assert_nil schema.maximum
    end

    def test_apply_numeric_range_on_string_type_is_skipped
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)

      _stdout, stderr = capture_io do
        RangeUtils.apply_to_schema(schema, 1..10)
      end

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_nil schema.enum
      assert_match(/Numeric range.*ignored on non-numeric/, stderr)
    end

    def test_apply_string_range_sets_enum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
      RangeUtils.apply_to_schema(schema, "a".."e")

      assert_equal %w[a b c d e], schema.enum
    end

    def test_apply_wide_string_range_does_not_set_enum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
      RangeUtils.apply_to_schema(schema, "a".."zzzzzz")

      assert_nil schema.enum
    end

    def test_apply_endless_numeric_range_sets_minimum_only
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 1..)

      assert_equal 1, schema.minimum
      assert_nil schema.maximum
    end

    def test_apply_beginless_numeric_range_sets_maximum_only
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, ..10)

      assert_nil schema.minimum
      assert_equal 10, schema.maximum
    end

    def test_apply_string_range_on_integer_type_is_skipped
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)

      _stdout, stderr = capture_io do
        RangeUtils.apply_to_schema(schema, "a".."z")
      end

      assert_nil schema.enum
      assert_nil schema.minimum
      assert_match(/Non-numeric range.*ignored on numeric/, stderr)
    end

    def test_apply_infinity_range_skips_infinite_bounds
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::NUMBER)
      RangeUtils.apply_to_schema(schema, -Float::INFINITY..Float::INFINITY)

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_nil schema.exclusive_maximum
    end

    def test_apply_exclusive_infinity_range_does_not_set_exclusive_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 1...Float::INFINITY)

      assert_equal 1, schema.minimum
      assert_nil schema.maximum
      assert_nil schema.exclusive_maximum
    end

    def test_apply_numeric_range_on_number_type
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::NUMBER)
      RangeUtils.apply_to_schema(schema, 0.0..1.0)

      assert_in_delta 0.0, schema.minimum
      assert_in_delta 1.0, schema.maximum
    end

    def test_apply_numeric_range_on_nil_type_warns
      schema = ApiModel::Schema.new(type: nil)

      _stdout, stderr = capture_io do
        RangeUtils.apply_to_schema(schema, 1..10)
      end

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_match(/Numeric range.*ignored on non-numeric/, stderr)
    end
  end
end
