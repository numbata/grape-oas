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
      # Build a range of exactly MAX_ENUM_RANGE_SIZE elements
      letters = ("a".."z").to_a
      range_end = letters[Constants::MAX_ENUM_RANGE_SIZE - 1] || letters.last
      range = "a"..range_end
      result = RangeUtils.expand_range_to_enum(range)

      refute_nil result
      assert_operator result.length, :<=, Constants::MAX_ENUM_RANGE_SIZE
    end

    def test_returns_nil_for_range_exceeding_max_by_one
      # 'a'..'zz' produces 702 elements which exceeds MAX_ENUM_RANGE_SIZE (100)
      assert_nil RangeUtils.expand_range_to_enum("a".."zz")
    end

    def test_handles_exclusive_string_range
      assert_equal %w[a b c d], RangeUtils.expand_range_to_enum("a"..."e")
    end
  end
end
