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
    end
  end
end
