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

      def test_schema_with_string_default_emits_default
        schema = ApiModel::Schema.new(type: "string")
        schema.default = "pending"

        result = OAS3::Schema.new(schema).build

        assert_equal "pending", result["default"]
      end

      def test_schema_with_integer_zero_default_emits_default
        schema = ApiModel::Schema.new(type: "integer")
        schema.default = 0

        result = OAS3::Schema.new(schema).build

        assert result.key?("default"), "expected 'default' key to be present"
        assert_equal 0, result["default"]
      end

      def test_schema_with_false_default_emits_default
        schema = ApiModel::Schema.new(type: "boolean")
        schema.default = false

        result = OAS3::Schema.new(schema).build

        assert result.key?("default"), "expected 'default' key to be present"
        assert_equal false, result["default"] # rubocop:disable Minitest/RefuteFalse
      end

      def test_schema_without_default_does_not_emit_default_key
        schema = ApiModel::Schema.new(type: "string")

        result = OAS3::Schema.new(schema).build

        refute result.key?("default")
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

      def test_integer_enum_normalized_type_array
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = %w[1 2 3]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, 3], result["enum"]
      end

      def test_number_enum_normalized_type_array
        schema = ApiModel::Schema.new(type: "number", nullable: true)
        schema.enum = %w[1.5 2.5]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[number null], result["type"]
        assert_equal [1.5, 2.5], result["enum"]
      end

      def test_boolean_enum_normalized_type_array
        schema = ApiModel::Schema.new(type: "boolean", nullable: true)
        schema.enum = [true, false]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[boolean null], result["type"]
        assert_equal [true, false], result["enum"]
      end

      def test_non_nullable_integer_enum_normalized_type_array
        schema = ApiModel::Schema.new(type: "integer")
        schema.enum = %w[1 2 3]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal "integer", result["type"]
        assert_equal [1, 2, 3], result["enum"]
      end

      def test_nullable_integer_enum_preserves_nil_type_array
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = [1, 2, nil]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, nil], result["enum"]
      end

      def test_sanitize_drops_incompatible_enum_for_boolean_with_nil
        schema = ApiModel::Schema.new(type: "boolean", nullable: true)
        schema.enum = ["yes", "no", nil]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        refute result.key?("enum"), "enum with non-boolean values should be dropped"
      end

      def test_null_only_type_drops_enum
        schema = ApiModel::Schema.new(type: "null", nullable: true)
        schema.enum = %w[a b]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[null], result["type"]
        refute result.key?("enum"), "null-only type has no base type so enum is dropped"
      end

      def test_nullable_integer_enum_deduplicates_nils_type_array
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = [1, nil, 2, nil]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal [1, 2, nil], result["enum"]
      end

      def test_coerce_example_with_type_array_integer
        schema = ApiModel::Schema.new(type: "integer", nullable: true, examples: ["42"])

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[integer null], result["type"]
        assert_equal 42, result["example"]
      end

      # === nullable_strategy tests ===

      def test_keyword_strategy_emits_nullable_true
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "string", result["type"]
        assert result["nullable"]
      end

      def test_keyword_strategy_does_not_emit_nullable_when_not_nullable
        schema = ApiModel::Schema.new(type: "string")

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "string", result["type"]
        refute result.key?("nullable")
      end

      def test_keyword_strategy_preserves_nil_in_enum
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = [1, 2, nil]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "integer", result["type"]
        assert result["nullable"]
        assert_equal [1, 2, nil], result["enum"]
      end

      def test_extension_strategy_preserves_nil_in_enum
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = [1, 2, nil]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "integer", result["type"]
        assert result["x-nullable"]
        assert_equal [1, 2, nil], result["enum"]
      end

      def test_type_array_strategy_produces_type_array_with_null
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[string null], result["type"]
        refute result.key?("nullable")
      end

      def test_default_strategy_is_keyword
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        result = OAS3::Schema.new(schema).build

        assert_equal "string", result["type"]
        assert result["nullable"]
      end

      def test_response_builder_defaults_to_keyword_nullable_strategy
        schema = ApiModel::Schema.new(type: "string", nullable: true)
        media_type = ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
        response = ApiModel::Response.new(http_status: 200, description: "ok", media_types: [media_type])

        result = OAS3::Response.new([response]).build
        built_schema = result["200"]["content"]["application/json"]["schema"]

        assert_equal "string", built_schema["type"]
        assert built_schema["nullable"]
      end

      # === $ref + allOf wrapping tests ===

      def test_ref_with_description_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", description: "A related entity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        refute child.key?("$ref")
      end

      def test_ref_without_description_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("allOf")
      end

      def test_ref_with_description_and_nullable_keyword_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", description: "A related entity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        assert child["nullable"]
        refute child.key?("$ref")
      end

      def test_ref_nullable_enum_preserves_nil_keyword
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", type: "integer", nullable: true)
        ref_schema.enum = [1, 2, nil]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal [1, 2, nil], child["enum"]
        assert child["nullable"]
      end

      def test_ref_nullable_enum_preserves_nil_extension
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", type: "integer", nullable: true)
        ref_schema.enum = [1, 2, nil]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal [1, 2, nil], child["enum"]
        assert child["x-nullable"]
      end

      def test_ref_nullable_enum_preserves_nil_type_array
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", type: "integer", nullable: true)
        ref_schema.enum = [1, 2, nil]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal [1, 2, nil], child["enum"]
      end

      def test_ref_with_nullable_keyword_only_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert child["nullable"]
        refute child.key?("$ref")
      end

      def test_ref_without_nullable_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("allOf")
        refute child.key?("nullable")
      end

      def test_ref_with_nullable_type_array_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        child = result["properties"]["child"]

        # TYPE_ARRAY nullability cannot be expressed on $ref — stays as plain ref
        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("allOf")
      end

      def test_ref_with_description_and_nullable_type_array_wraps_for_description_only
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", description: "A related entity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        child = result["properties"]["child"]

        # Wraps for description, but TYPE_ARRAY nullability cannot be expressed on $ref
        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        refute child.key?("$ref")
        refute child.key?("type")
      end

      # === Composition: default propagation tests ===

      def test_allof_schema_with_default
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.default = { "role" => "guest" }

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal({ "role" => "guest" }, result["default"])
      end

      def test_oneof_schema_with_default
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.default = "option_a"

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal "option_a", result["default"]
      end

      def test_anyof_schema_with_default
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(any_of: [variant])
        schema.default = "option_a"

        result = OAS3::Schema.new(schema).build

        assert result.key?("anyOf")
        assert_equal "option_a", result["default"]
      end

      def test_allof_schema_without_default
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])

        result = OAS3::Schema.new(schema).build

        refute result.key?("default")
      end

      # === Composition: enum propagation tests ===

      def test_allof_schema_with_enum
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.enum = %w[a b c]

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal %w[a b c], result["enum"]
      end

      def test_oneof_schema_with_enum
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.enum = %w[x y]

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal %w[x y], result["enum"]
      end

      def test_anyof_schema_with_enum
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(any_of: [variant])
        schema.enum = %w[x y]

        result = OAS3::Schema.new(schema).build

        assert result.key?("anyOf")
        assert_equal %w[x y], result["enum"]
      end

      # === Composition: format and type propagation tests ===

      def test_allof_schema_with_type_and_format
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "object")
        schema.format = "custom"

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "object", result["type"]
        assert_equal "custom", result["format"]
      end

      def test_composition_with_nullable_type_array_emits_type_array
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(one_of: [child], type: "string", nullable: true)

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert result.key?("oneOf")
        assert_equal %w[string null], result["type"]
      end

      def test_oneof_schema_with_format
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.format = "date-time"

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal "date-time", result["format"]
      end

      # === Composition: constraints propagation tests ===

      def test_allof_schema_with_constraints
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.minimum = 0
        schema.maximum = 100
        schema.min_length = 1
        schema.max_length = 50

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal 0, result["minimum"]
        assert_equal 100, result["maximum"]
        assert_equal 1, result["minLength"]
        assert_equal 50, result["maxLength"]
      end

      def test_oneof_schema_with_constraints
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.min_items = 1
        schema.max_items = 5

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal 1, result["minItems"]
        assert_equal 5, result["maxItems"]
      end

      def test_anyof_schema_with_pattern
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(any_of: [variant])
        schema.pattern = "^[a-z]+$"

        result = OAS3::Schema.new(schema).build

        assert result.key?("anyOf")
        assert_equal "^[a-z]+$", result["pattern"]
      end

      # === Composition: exclusive bounds under TYPE_ARRAY strategy ===

      def test_allof_schema_with_exclusive_bounds_type_array
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.minimum = 0
        schema.exclusive_minimum = true
        schema.maximum = 100
        schema.exclusive_maximum = true

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert result.key?("allOf")
        assert_equal 0, result["exclusiveMinimum"]
        assert_equal 100, result["exclusiveMaximum"]
        refute result.key?("minimum")
        refute result.key?("maximum")
      end

      def test_ref_with_exclusive_bounds_type_array
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.minimum = 5
        ref_schema.exclusive_minimum = true
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal 5, child["exclusiveMinimum"]
        refute child.key?("minimum")
      end

      # === Composition: enum normalization ===

      def test_allof_schema_normalizes_integer_enum
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "integer")
        schema.enum = %w[1 2 3]

        result = OAS3::Schema.new(schema).build

        assert_equal [1, 2, 3], result["enum"]
      end

      def test_allof_schema_normalizes_integer_enum_type_array
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "integer", nullable: true)
        schema.enum = %w[1 2 3]

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, 3], result["enum"]
      end

      def test_allof_schema_sanitizes_incompatible_enum
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "boolean")
        schema.enum = %w[true false]

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        refute result.key?("enum"), "string enum incompatible with boolean type should be dropped"
      end

      # === $ref + allOf wrapping: extensions propagation tests ===

      def test_ref_with_extensions_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(
          canonical_name: "MyEntity",
          extensions: { "x-custom" => "value" },
        )
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "value", child["x-custom"]
      end

      # === Composition: extensions propagation tests ===

      def test_allof_schema_with_extensions
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(
          all_of: [child],
          extensions: { "x-custom" => "allof-value" },
        )

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "allof-value", result["x-custom"]
      end

      def test_oneof_schema_with_extensions
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(
          one_of: [variant],
          extensions: { "x-tag" => "poly" },
        )

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal "poly", result["x-tag"]
      end

      def test_anyof_schema_with_extensions
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(
          any_of: [variant],
          extensions: { "x-tag" => "poly" },
        )

        result = OAS3::Schema.new(schema).build

        assert result.key?("anyOf")
        assert_equal "poly", result["x-tag"]
      end

      # === $ref + allOf wrapping: default propagation tests ===

      def test_ref_with_default_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.default = "guest"
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "guest", child["default"]
        refute child.key?("$ref")
      end

      def test_ref_with_false_default_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.default = false
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal false, child["default"] # rubocop:disable Minitest/RefuteFalse
      end

      def test_ref_without_default_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("default")
      end

      # === $ref + allOf wrapping: enum propagation tests ===

      def test_ref_with_enum_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.enum = %w[admin user guest]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal %w[admin user guest], child["enum"]
        refute child.key?("$ref")
      end

      def test_ref_with_incompatible_enum_drops_enum
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", type: "boolean")
        ref_schema.enum = %w[true false]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("enum"), "string enum incompatible with boolean type should be dropped"
      end

      def test_ref_without_enum_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("enum")
      end

      # === $ref + allOf wrapping: constraints propagation tests ===

      def test_ref_with_numeric_constraints_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.minimum = 0
        ref_schema.maximum = 100
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal 0, child["minimum"]
        assert_equal 100, child["maximum"]
      end

      def test_ref_with_string_constraints_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.min_length = 1
        ref_schema.max_length = 255
        ref_schema.pattern = "^[a-z]+$"
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal 1, child["minLength"]
        assert_equal 255, child["maxLength"]
        assert_equal "^[a-z]+$", child["pattern"]
      end

      def test_ref_with_array_constraints_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.min_items = 1
        ref_schema.max_items = 10
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal 1, child["minItems"]
        assert_equal 10, child["maxItems"]
      end

      def test_ref_with_exclusive_bounds_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.minimum = 0
        ref_schema.exclusive_minimum = true
        ref_schema.maximum = 100
        ref_schema.exclusive_maximum = true
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal 0, child["minimum"]
        assert child["exclusiveMinimum"]
        assert_equal 100, child["maximum"]
        assert child["exclusiveMaximum"]
      end

      def test_ref_without_constraints_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/components/schemas/MyEntity", child["$ref"]
        refute child.key?("minimum")
        refute child.key?("minLength")
        refute child.key?("minItems")
      end

      # === $ref + allOf wrapping: combined attributes test ===

      def test_ref_with_multiple_attributes_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(
          canonical_name: "MyEntity",
          description: "A related entity",
          extensions: { "x-deprecated" => true },
        )
        ref_schema.default = "guest"
        ref_schema.enum = %w[admin user guest]
        ref_schema.min_length = 1
        ref_schema.max_length = 50
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS3::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/components/schemas/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        assert_equal "guest", child["default"]
        assert_equal %w[admin user guest], child["enum"]
        assert_equal 1, child["minLength"]
        assert_equal 50, child["maxLength"]
        assert child["x-deprecated"]
        refute child.key?("$ref")
      end

      # === Array items: description/nullable hoisting tests ===

      def test_array_ref_items_description_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", description: "An item")
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, ref_tracker).build

        assert_equal "array", result["type"]
        assert_equal "An item", result["description"]
        assert_equal({ "$ref" => "#/components/schemas/ItemEntity" }, result["items"])
      end

      def test_array_ref_items_nullable_keyword_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "array", result["type"]
        assert result["nullable"], "nullable should be on the outer array"
        assert_equal({ "$ref" => "#/components/schemas/ItemEntity" }, result["items"])
      end

      def test_array_ref_items_nullable_extension_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "array", result["type"]
        assert result["x-nullable"], "x-nullable should be on the outer array"
        assert_equal({ "$ref" => "#/components/schemas/ItemEntity" }, result["items"])
      end

      def test_array_ref_items_nullable_type_array_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[array null], result["type"]
        assert_equal({ "$ref" => "#/components/schemas/ItemEntity" }, result["items"])
      end

      def test_array_ref_items_description_does_not_overwrite_outer
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", description: "Item desc")
        array_schema = ApiModel::Schema.new(type: "array", description: "Array desc", items: items_schema)

        result = OAS3::Schema.new(array_schema, ref_tracker).build

        assert_equal "Array desc", result["description"], "Outer array description should take precedence"
        assert_equal({ "$ref" => "#/components/schemas/ItemEntity" }, result["items"])
      end

      def test_array_inline_items_description_hoisted_to_outer_array
        items_schema = ApiModel::Schema.new(type: "string", description: "A string item")
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema).build

        assert_equal "array", result["type"]
        assert_equal "A string item", result["description"]
        refute result["items"].key?("description"), "Description should not remain on items"
      end

      def test_array_inline_items_nullable_preserved_on_items
        items_schema = ApiModel::Schema.new(type: "string", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "array", result["type"]
        refute result["nullable"], "nullable should NOT be on the outer array for inline items"
        assert result["items"]["nullable"], "nullable should remain on inline items"
      end

      def test_array_inline_allof_items_nullable_preserved
        child = ApiModel::Schema.new(type: "object")
        items_schema = ApiModel::Schema.new(all_of: [child], nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "array", result["type"]
        refute result["nullable"], "nullable should NOT be on the outer array"
        assert result["items"]["nullable"], "nullable should be on the composed items schema"
        assert result["items"]["allOf"], "allOf should be present on items"
      end

      def test_array_inline_oneof_items_nullable_preserved
        variant = ApiModel::Schema.new(type: "string")
        items_schema = ApiModel::Schema.new(one_of: [variant], nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "array", result["type"]
        refute result["x-nullable"], "x-nullable should NOT be on the outer array"
        assert result["items"]["x-nullable"], "x-nullable should be on the composed items schema"
        assert result["items"]["oneOf"], "oneOf should be present on items"
      end

      # === File type normalization (OAS 3.0) ===
      # OAS 3.0 does not support `type: file`; files are represented as
      # `type: string, format: binary`.

      def test_file_type_becomes_string_with_binary_format
        schema = ApiModel::Schema.new(type: "file")

        result = OAS3::Schema.new(schema).build

        assert_equal "string", result["type"]
        assert_equal "binary", result["format"]
      end

      def test_array_of_files_items_become_string_with_binary_format
        items = ApiModel::Schema.new(type: "file")
        array = ApiModel::Schema.new(type: "array", items: items)

        result = OAS3::Schema.new(array).build

        assert_equal "array", result["type"]
        assert_equal({ "type" => "string", "format" => "binary" }, result["items"])
      end

      def test_file_typed_property_becomes_string_with_binary_format
        file_prop = ApiModel::Schema.new(type: "file")
        object = ApiModel::Schema.new(type: "object")
        object.add_property("avatar", file_prop)

        result = OAS3::Schema.new(object).build

        assert_equal({ "type" => "string", "format" => "binary" }, result["properties"]["avatar"])
      end

      def test_nullable_file_type_array_strategy_becomes_nullable_string_with_binary_format
        schema = ApiModel::Schema.new(type: "file", nullable: true)

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY).build

        assert_equal %w[string null], result["type"]
        assert_equal "binary", result["format"]
      end

      def test_nullable_file_keyword_strategy_becomes_string_with_binary_format_and_nullable
        schema = ApiModel::Schema.new(type: "file", nullable: true)

        result = OAS3::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "string", result["type"]
        assert_equal "binary", result["format"]
        assert result["nullable"]
      end

      def test_allof_with_file_type_normalizes
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "file")

        result = OAS3::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "string", result["type"]
        assert_equal "binary", result["format"]
      end

      def test_oneof_with_file_type_normalizes
        variant = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(one_of: [variant], type: "file")

        result = OAS3::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal "string", result["type"]
        assert_equal "binary", result["format"]
      end

      def test_anyof_with_file_type_normalizes
        variant = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(any_of: [variant], type: "file")

        result = OAS3::Schema.new(schema).build

        assert result.key?("anyOf")
        assert_equal "string", result["type"]
        assert_equal "binary", result["format"]
      end
    end
  end
end
