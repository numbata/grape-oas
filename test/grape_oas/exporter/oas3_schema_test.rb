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

      def test_array_inline_items_nullable_stripped_and_hoisted
        items_schema = ApiModel::Schema.new(type: "string", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS3::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::KEYWORD).build

        assert_equal "array", result["type"]
        assert result["nullable"], "nullable should be on the outer array"
        refute result["items"].key?("nullable"), "nullable should not remain on items"
      end
    end
  end
end
