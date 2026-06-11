# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorArrayExampleTest < Minitest::Test
      # is_array: true with an array-valued example — example belongs on the array wrapper.

      class ArrayExampleEntity < Grape::Entity
        expose :species, documentation: { type: "string", is_array: true, example: %w[cat dog] }
        expose :counts,  documentation: { type: "integer", is_array: true, example: [1, 2] }
      end

      def test_array_valued_string_example_is_placed_on_array_schema
        schema = EntityIntrospector.new(ArrayExampleEntity).build_schema
        species = schema.properties["species"]

        assert_equal Constants::SchemaTypes::ARRAY, species.type
        assert_equal %w[cat dog], species.examples
        assert_nil species.items.examples
      end

      def test_array_valued_integer_example_is_placed_on_array_schema
        schema = EntityIntrospector.new(ArrayExampleEntity).build_schema
        counts = schema.properties["counts"]

        assert_equal Constants::SchemaTypes::ARRAY, counts.type
        assert_equal [1, 2], counts.examples
        assert_nil counts.items.examples
      end

      # is_array: true with a scalar example — example stays on items (valid per OAS).

      class ScalarExampleOnArrayEntity < Grape::Entity
        expose :label, documentation: { type: "string", is_array: true, example: "cat" }
      end

      def test_scalar_example_on_is_array_exposure_stays_on_items
        schema = EntityIntrospector.new(ScalarExampleOnArrayEntity).build_schema
        label = schema.properties["label"]

        assert_equal Constants::SchemaTypes::ARRAY, label.type
        assert_nil label.examples
        assert_equal "cat", label.items.examples
      end
    end
  end
end
