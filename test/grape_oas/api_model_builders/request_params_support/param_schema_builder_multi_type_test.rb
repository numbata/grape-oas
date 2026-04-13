# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Unit tests for ParamSchemaBuilder with multi-type and nullable types.
      #
      # These tests exercise the schema builder directly with pre-stringified types
      # because Grape >= 3.2 rejects NilClass as a coercible type and string types
      # at definition time.
      class ParamSchemaBuilderMultiTypeTest < Minitest::Test
        def test_typed_array_not_treated_as_multi_type
          schema = ParamSchemaBuilder.build(
            type: "[String]", documentation: {},
          )

          assert_equal Constants::SchemaTypes::ARRAY, schema.type
          assert_nil schema.one_of
          assert_equal Constants::SchemaTypes::STRING, schema.items.type
        end

        def test_nullable_string_with_enum
          schema = ParamSchemaBuilder.build(
            type: "[String, NilClass]", values: %w[visible hidden], documentation: {},
          )

          # [String, NilClass] is optimized to nullable string (not oneOf)
          assert_equal Constants::SchemaTypes::STRING, schema.type
          assert schema.nullable
          assert_equal %w[visible hidden], schema.enum
        end

        def test_three_types_uses_one_of
          schema = ParamSchemaBuilder.build(
            type: "[String, Integer, NilClass]", values: %w[a b c], documentation: {},
          )

          # NilClass is filtered out, represented via nullable property
          refute_nil schema.one_of
          assert_equal 2, schema.one_of.size
          assert schema.nullable

          string_variant = schema.one_of.find { |s| s.type == Constants::SchemaTypes::STRING }

          assert_equal %w[a b c], string_variant.enum

          integer_variant = schema.one_of.find { |s| s.type == Constants::SchemaTypes::INTEGER }

          assert_nil integer_variant.enum
        end

        def test_integer_range_on_one_of
          schema = ParamSchemaBuilder.build(
            type: "[Integer, String, NilClass]", values: 1..10, documentation: {},
          )

          refute_nil schema.one_of

          integer_variant = schema.one_of.find { |s| s.type == Constants::SchemaTypes::INTEGER }
          string_variant = schema.one_of.find { |s| s.type == Constants::SchemaTypes::STRING }

          refute_nil integer_variant
          assert_equal 1, integer_variant.minimum
          assert_equal 10, integer_variant.maximum

          refute_nil string_variant
          assert_nil string_variant.minimum
          assert_nil string_variant.maximum
        end
      end
    end
  end
end
