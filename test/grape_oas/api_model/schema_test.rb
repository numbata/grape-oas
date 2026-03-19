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
    end
  end
end
