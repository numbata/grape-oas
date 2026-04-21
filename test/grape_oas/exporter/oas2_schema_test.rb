# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2SchemaTest < Minitest::Test
      def test_merges_extensions_into_output
        schema = ApiModel::Schema.new(
          type: "string",
          extensions: { "x-nullable" => true, "x-deprecated" => "Use 'status' instead" },
        )

        result = OAS2::Schema.new(schema).build

        assert_equal "string", result["type"]
        assert result["x-nullable"]
        assert_equal "Use 'status' instead", result["x-deprecated"]
      end

      def test_extensions_on_object_schema
        schema = ApiModel::Schema.new(
          type: "object",
          extensions: { "x-custom" => { "key" => "value" } },
        )
        schema.add_property("name", ApiModel::Schema.new(type: "string"))

        result = OAS2::Schema.new(schema).build

        assert_equal "object", result["type"]
        assert_equal({ "key" => "value" }, result["x-custom"])
        assert result["properties"]["name"]
      end

      def test_nil_extensions_does_not_add_keys
        schema = ApiModel::Schema.new(type: "integer")

        result = OAS2::Schema.new(schema).build

        assert_equal "integer", result["type"]
        refute result.key?("x-nullable")
      end

      def test_composition_with_type_preserves_type_and_extensions
        # When schema has both type and composition (e.g., any_of), prefer type with extensions
        # This allows patterns like type: "object" + x-anyOf extension
        ref_schema1 = ApiModel::Schema.new(canonical_name: "TypeA")
        ref_schema2 = ApiModel::Schema.new(canonical_name: "TypeB")

        schema = ApiModel::Schema.new(
          type: "object",
          any_of: [ref_schema1, ref_schema2],
          extensions: {
            "x-anyOf" => [
              { "$ref" => "#/definitions/TypeA" },
              { "$ref" => "#/definitions/TypeB" }
            ]
          },
        )

        result = OAS2::Schema.new(schema).build

        assert_equal "object", result["type"]
        assert_equal 2, result["x-anyOf"].size
        assert_equal({ "$ref" => "#/definitions/TypeA" }, result["x-anyOf"][0])
        assert_equal({ "$ref" => "#/definitions/TypeB" }, result["x-anyOf"][1])
      end

      def test_composition_without_type_uses_first_ref
        # When schema has composition but no type, fall back to first ref
        ref_schema1 = ApiModel::Schema.new(canonical_name: "TypeA")
        ref_schema2 = ApiModel::Schema.new(canonical_name: "TypeB")

        schema = ApiModel::Schema.new(
          any_of: [ref_schema1, ref_schema2],
        )

        result = OAS2::Schema.new(schema).build

        assert_equal "#/definitions/TypeA", result["$ref"]
        refute result.key?("type")
      end

      # === nullable_strategy: Constants::NullableStrategy::EXTENSION tests ===

      def test_extension_strategy_emits_x_nullable_on_nullable_schema
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        result = OAS2::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "string", result["type"]
        assert result["x-nullable"]
      end

      def test_extension_strategy_does_not_emit_x_nullable_when_not_nullable
        schema = ApiModel::Schema.new(type: "string")

        result = OAS2::Schema.new(schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "string", result["type"]
        refute result.key?("x-nullable")
      end

      def test_no_strategy_does_not_emit_x_nullable
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        result = OAS2::Schema.new(schema).build

        assert_equal "string", result["type"]
        refute result.key?("x-nullable")
      end

      def test_extension_strategy_emits_x_nullable_on_ref_schema
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert child["x-nullable"]
      end

      def test_extension_strategy_does_not_emit_x_nullable_on_non_nullable_ref
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        child = result["properties"]["child"]

        assert_equal "#/definitions/MyEntity", child["$ref"]
        refute child.key?("x-nullable")
      end

      # === $ref + allOf wrapping tests ===

      def test_ref_with_description_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", description: "A related entity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        refute child.key?("$ref")
      end

      def test_ref_without_description_stays_plain
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal "#/definitions/MyEntity", child["$ref"]
        refute child.key?("allOf")
      end

      def test_ref_with_description_and_nullable_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", description: "A related entity", nullable: true)
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "A related entity", child["description"]
        assert child["x-nullable"]
        refute child.key?("$ref")
      end

      # === Composition: default propagation tests ===

      def test_allof_schema_with_default
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.default = { "role" => "guest" }

        result = OAS2::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal({ "role" => "guest" }, result["default"])
      end

      def test_first_of_schema_with_default
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.default = "option_a"

        result = OAS2::Schema.new(schema).build

        assert_equal "option_a", result["default"]
      end

      def test_allof_schema_without_default
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])

        result = OAS2::Schema.new(schema).build

        refute result.key?("default")
      end

      # === Composition: enum propagation tests ===

      def test_allof_schema_with_enum
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.enum = %w[a b c]

        result = OAS2::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal %w[a b c], result["enum"]
      end

      def test_first_of_schema_with_enum
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.enum = %w[x y]

        result = OAS2::Schema.new(schema).build

        assert_equal %w[x y], result["enum"]
      end

      # === Composition: format and type propagation tests ===

      def test_allof_schema_with_type_and_format
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "object")
        schema.format = "custom"

        result = OAS2::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "object", result["type"]
        assert_equal "custom", result["format"]
      end

      # === Composition: constraints propagation tests ===

      def test_allof_schema_with_constraints
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child])
        schema.minimum = 0
        schema.maximum = 100
        schema.min_length = 1

        result = OAS2::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal 0, result["minimum"]
        assert_equal 100, result["maximum"]
        assert_equal 1, result["minLength"]
      end

      def test_first_of_schema_with_constraints
        variant = ApiModel::Schema.new(type: "string")
        schema = ApiModel::Schema.new(one_of: [variant])
        schema.min_length = 5
        schema.pattern = "^[A-Z]"

        result = OAS2::Schema.new(schema).build

        assert_equal 5, result["minLength"]
        assert_equal "^[A-Z]", result["pattern"]
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

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "value", child["x-custom"]
      end

      # === Composition: extensions propagation tests ===

      def test_allof_schema_with_extensions
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(
          all_of: [child],
          extensions: { "x-custom" => "allof-value" },
        )

        result = OAS2::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "allof-value", result["x-custom"]
      end

      # === $ref + allOf wrapping: default propagation tests ===

      def test_ref_with_default_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.default = "guest"
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "guest", child["default"]
        refute child.key?("$ref")
      end

      def test_ref_with_false_default_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.default = false
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal false, child["default"] # rubocop:disable Minitest/RefuteFalse
      end

      # === $ref + allOf wrapping: enum propagation tests ===

      def test_ref_with_enum_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.enum = %w[admin user guest]
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal %w[admin user guest], child["enum"]
        refute child.key?("$ref")
      end

      # === $ref + allOf wrapping: format and type propagation tests ===

      def test_ref_with_format_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.format = "date-time"
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "date-time", child["format"]
        refute child.key?("$ref")
      end

      def test_ref_with_type_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity", type: "string")
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal "string", child["type"]
      end

      # === $ref + allOf wrapping: constraints propagation tests ===

      def test_ref_with_numeric_constraints_wraps_in_allof
        ref_tracker = Set.new
        ref_schema = ApiModel::Schema.new(canonical_name: "MyEntity")
        ref_schema.minimum = 0
        ref_schema.maximum = 100
        parent_schema = ApiModel::Schema.new(type: "object")
        parent_schema.add_property("child", ref_schema)

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
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

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
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

        result = OAS2::Schema.new(parent_schema, ref_tracker).build

        child = result["properties"]["child"]

        assert_equal [{ "$ref" => "#/definitions/MyEntity" }], child["allOf"]
        assert_equal 1, child["minItems"]
        assert_equal 10, child["maxItems"]
      end

      # === Array items: description/nullable hoisting tests ===

      def test_array_ref_items_description_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", description: "An item")
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS2::Schema.new(array_schema, ref_tracker).build

        assert_equal "array", result["type"]
        assert_equal "An item", result["description"]
        assert_equal({ "$ref" => "#/definitions/ItemEntity" }, result["items"])
        refute result["items"].key?("allOf")
      end

      def test_array_ref_items_nullable_hoisted_to_outer_array
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS2::Schema.new(array_schema, ref_tracker, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "array", result["type"]
        assert result["x-nullable"], "x-nullable should be on the outer array"
        assert_equal({ "$ref" => "#/definitions/ItemEntity" }, result["items"])
      end

      def test_array_ref_items_description_does_not_overwrite_outer
        ref_tracker = Set.new
        items_schema = ApiModel::Schema.new(canonical_name: "ItemEntity", description: "Item desc")
        array_schema = ApiModel::Schema.new(type: "array", description: "Array desc", items: items_schema)

        result = OAS2::Schema.new(array_schema, ref_tracker).build

        assert_equal "Array desc", result["description"], "Outer array description should take precedence"
        assert_equal({ "$ref" => "#/definitions/ItemEntity" }, result["items"])
      end

      def test_array_inline_items_description_hoisted_to_outer_array
        items_schema = ApiModel::Schema.new(type: "string", description: "A string item")
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS2::Schema.new(array_schema).build

        assert_equal "array", result["type"]
        assert_equal "A string item", result["description"]
        refute result["items"].key?("description"), "Description should not remain on items"
      end

      def test_array_inline_items_nullable_preserved_on_items
        items_schema = ApiModel::Schema.new(type: "string", nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS2::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "array", result["type"]
        refute result["x-nullable"], "x-nullable should NOT be on the outer array for inline items"
        assert result["items"]["x-nullable"], "x-nullable should remain on inline items"
      end

      def test_array_inline_allof_items_nullable_preserved
        child = ApiModel::Schema.new(type: "object")
        items_schema = ApiModel::Schema.new(all_of: [child], nullable: true)
        array_schema = ApiModel::Schema.new(type: "array", items: items_schema)

        result = OAS2::Schema.new(array_schema, nil, nullable_strategy: Constants::NullableStrategy::EXTENSION).build

        assert_equal "array", result["type"]
        refute result["x-nullable"], "x-nullable should NOT be on the outer array"
        assert result["items"]["x-nullable"], "x-nullable should be on the composed items schema"
        assert result["items"]["allOf"], "allOf should be present on items"
      end

      # === Default value tests ===

      def test_schema_with_string_default_emits_default
        schema = ApiModel::Schema.new(type: "string")
        schema.default = "pending"

        result = OAS2::Schema.new(schema).build

        assert_equal "pending", result["default"]
      end

      def test_schema_with_integer_zero_default_emits_default
        schema = ApiModel::Schema.new(type: "integer")
        schema.default = 0

        result = OAS2::Schema.new(schema).build

        assert result.key?("default"), "expected 'default' key to be present"
        assert_equal 0, result["default"]
      end

      def test_schema_with_false_default_emits_default
        schema = ApiModel::Schema.new(type: "boolean")
        schema.default = false

        result = OAS2::Schema.new(schema).build

        assert result.key?("default"), "expected 'default' key to be present"
        assert_equal false, result["default"] # rubocop:disable Minitest/RefuteFalse
      end

      def test_schema_without_default_does_not_emit_default_key
        schema = ApiModel::Schema.new(type: "string")

        result = OAS2::Schema.new(schema).build

        refute result.key?("default")
      end

      # === Inline nested object with enum properties ===

      def test_inline_nested_object_with_enum_properties
        inner = ApiModel::Schema.new(type: "string")
        inner.enum = %w[left center right]

        outer = ApiModel::Schema.new(type: "object")
        outer.add_property("align", inner)

        parent = ApiModel::Schema.new(type: "object")
        parent.add_property("textAlignment", outer)

        result = OAS2::Schema.new(parent).build

        ta = result["properties"]["textAlignment"]

        assert_equal "object", ta["type"]
        assert_equal %w[left center right], ta["properties"]["align"]["enum"]
      end

      # === Inline nested object with minimum/maximum ===

      def test_inline_nested_object_with_min_max
        inner = ApiModel::Schema.new(type: "integer")
        inner.minimum = -2
        inner.maximum = 2

        outer = ApiModel::Schema.new(type: "object")
        outer.add_property("offset", inner)

        result = OAS2::Schema.new(outer).build

        offset = result["properties"]["offset"]

        assert_equal "integer", offset["type"]
        assert_equal(-2, offset["minimum"])
        assert_equal 2, offset["maximum"]
      end
    end
  end
end
