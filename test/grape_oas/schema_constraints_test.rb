# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class SchemaConstraintsTest < Minitest::Test
    def test_applies_minimum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      SchemaConstraints.apply(schema, { minimum: 0 })

      assert_equal 0, schema.minimum
    end

    def test_applies_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      SchemaConstraints.apply(schema, { maximum: 100 })

      assert_equal 100, schema.maximum
    end

    def test_applies_min_length
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
      SchemaConstraints.apply(schema, { min_length: 1 })

      assert_equal 1, schema.min_length
    end

    def test_applies_max_length
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
      SchemaConstraints.apply(schema, { max_length: 255 })

      assert_equal 255, schema.max_length
    end

    def test_applies_pattern
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
      SchemaConstraints.apply(schema, { pattern: "^[a-z]+$" })

      assert_equal "^[a-z]+$", schema.pattern
    end

    def test_maximum_clears_exclusive_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      schema.exclusive_maximum = true
      SchemaConstraints.apply(schema, { maximum: 5 })

      assert_equal 5, schema.maximum
      assert_nil schema.exclusive_maximum
    end

    def test_minimum_without_maximum_preserves_exclusive_maximum
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      schema.exclusive_maximum = true
      SchemaConstraints.apply(schema, { minimum: 0 })

      assert_equal 0, schema.minimum
      assert schema.exclusive_maximum
    end

    def test_skips_keys_not_in_doc
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      SchemaConstraints.apply(schema, {})

      assert_nil schema.minimum
      assert_nil schema.maximum
      assert_nil schema.min_length
      assert_nil schema.max_length
      assert_nil schema.pattern
    end

    def test_applies_multiple_constraints
      schema = ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER)
      SchemaConstraints.apply(schema, { minimum: 1, maximum: 10 })

      assert_equal 1, schema.minimum
      assert_equal 10, schema.maximum
    end
  end
end
