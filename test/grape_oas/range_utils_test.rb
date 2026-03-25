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

    # === numeric_range? tests ===

    def test_numeric_range_returns_true_for_integer_range
      assert RangeUtils.numeric_range?(1..10)
    end

    def test_numeric_range_returns_true_for_float_range
      assert RangeUtils.numeric_range?(0.0..1.0)
    end

    def test_numeric_range_returns_true_for_endless_numeric_range
      assert RangeUtils.numeric_range?(1..)
    end

    def test_numeric_range_returns_false_for_string_range
      refute RangeUtils.numeric_range?("a".."z")
    end

    def test_numeric_range_returns_false_for_beginless_string_range
      refute RangeUtils.numeric_range?(..("z"))
    end

    # === apply_to_schema tests ===

    def test_apply_to_schema_warns_on_mixed_type_range
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      # Ruby prevents constructing a mixed-type Range directly, so simulate one
      mixed_range = Struct.new(:begin, :end, :exclude_end?).new(1, "z", false)

      log_output = capture_grape_oas_log { RangeUtils.apply_to_schema(schema, mixed_range) }

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_nil schema.enum
      assert_match(/Mixed-type range.*ignored/, log_output)
    end

    def test_apply_numeric_range_to_integer_schema
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_to_schema(schema, 1..10)

      assert_equal 1, schema.minimum
      assert_equal 10, schema.maximum
      refute schema.exclusive_maximum
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

      log_output = capture_grape_oas_log { RangeUtils.apply_to_schema(schema, 1..10) }

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_nil schema.enum
      assert_match(/Numeric range.*ignored on non-numeric/, log_output)
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

      log_output = capture_grape_oas_log { RangeUtils.apply_to_schema(schema, "a".."z") }

      assert_nil schema.enum
      assert_nil schema.minimum
      assert_match(/Non-numeric range.*ignored on numeric/, log_output)
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

      log_output = capture_grape_oas_log { RangeUtils.apply_to_schema(schema, 1..10) }

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_match(/Numeric range.*ignored on non-numeric/, log_output)
    end

    # === apply_numeric_range tests ===

    def test_apply_numeric_range_sets_min_max
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_numeric_range(schema, 1..10)

      assert_equal 1, schema.minimum
      assert_equal 10, schema.maximum
      refute schema.exclusive_maximum
    end

    def test_apply_numeric_range_exclusive_sets_exclusive_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_numeric_range(schema, 0...10)

      assert_equal 0, schema.minimum
      assert_equal 10, schema.maximum
      assert schema.exclusive_maximum
    end

    def test_apply_numeric_range_skips_infinite_bounds
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::NUMBER)
      RangeUtils.apply_numeric_range(schema, -Float::INFINITY..Float::INFINITY)

      assert_nil schema.minimum
      assert_nil schema.maximum
    end

    def test_apply_numeric_range_endless_sets_minimum_only
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_numeric_range(schema, 1..)

      assert_equal 1, schema.minimum
      assert_nil schema.maximum
    end

    def test_apply_numeric_range_skips_descending
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      RangeUtils.apply_numeric_range(schema, 10..1)

      assert_nil schema.minimum
      assert_nil schema.maximum
    end

    def test_apply_numeric_range_works_with_constraint_set
      # Verify it works with any object that has min/max/exclusive_maximum setters
      constraint_set = Introspectors::DryIntrospectorSupport::ConstraintExtractor::ConstraintSet.new
      RangeUtils.apply_numeric_range(constraint_set, 0...100)

      assert_equal 0, constraint_set.minimum
      assert_equal 100, constraint_set.maximum
      assert constraint_set.exclusive_maximum
    end
  end
end
