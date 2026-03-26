# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModel
    class SchemaTest < Minitest::Test
      def test_add_property_stores_schema
        schema = Schema.new(type: Constants::SchemaTypes::OBJECT)
        child = Schema.new(type: Constants::SchemaTypes::STRING)
        schema.add_property("name", child)

        assert_equal child, schema.properties["name"]
      end

      def test_add_property_adds_to_required
        schema = Schema.new(type: Constants::SchemaTypes::OBJECT)
        schema.add_property("name", Schema.new(type: Constants::SchemaTypes::STRING), required: true)

        assert_includes schema.required, "name"
      end

      def test_add_property_does_not_duplicate_required
        schema = Schema.new(type: Constants::SchemaTypes::OBJECT)
        child = Schema.new(type: Constants::SchemaTypes::STRING)

        schema.add_property("name", child, required: true)
        schema.add_property("name", child, required: true)

        assert_equal 1, schema.required.count("name")
      end

      def test_add_property_does_not_add_optional_to_required
        schema = Schema.new(type: Constants::SchemaTypes::OBJECT)
        schema.add_property("name", Schema.new(type: Constants::SchemaTypes::STRING), required: false)

        refute_includes schema.required, "name"
      end

      # --- initialize_copy (dup safety) ---

      def test_dup_properties_are_independent
        original = Schema.new(type: Constants::SchemaTypes::OBJECT)
        original.add_property("name", Schema.new(type: Constants::SchemaTypes::STRING), required: true)

        duped = original.dup
        duped.add_property("age", Schema.new(type: Constants::SchemaTypes::INTEGER), required: true)

        assert_includes duped.properties.keys, "age"
        refute_includes original.properties.keys, "age",
                        "adding a property to the dup must not mutate the original"
      end

      def test_dup_required_is_independent
        original = Schema.new(type: Constants::SchemaTypes::OBJECT)
        original.add_property("name", Schema.new(type: Constants::SchemaTypes::STRING), required: true)

        duped = original.dup
        duped.add_property("age", Schema.new(type: Constants::SchemaTypes::INTEGER), required: true)

        assert_includes duped.required, "age"
        refute_includes original.required, "age",
                        "adding a required field to the dup must not mutate the original"
      end

      def test_dup_defs_are_independent
        original = Schema.new(type: Constants::SchemaTypes::OBJECT, defs: { "Foo" => "bar" })

        duped = original.dup
        duped.defs["Baz"] = "qux"

        refute_includes original.defs.keys, "Baz",
                        "mutating defs on the dup must not affect the original"
      end

      def test_dup_property_values_are_independent
        child = Schema.new(type: Constants::SchemaTypes::STRING)
        original = Schema.new(type: Constants::SchemaTypes::OBJECT)
        original.add_property("name", child, required: true)

        duped = original.dup
        duped.properties["name"].enum = %w[a b]

        assert_nil child.enum,
                   "mutating a property schema on the dup must not affect the original's property"
      end
    end
  end
end
