# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorConditionsTest < Minitest::Test
      class DetailEntity < Grape::Entity
        expose :a, documentation: { type: String }
        expose :b, documentation: { type: Integer }
      end

      class ConditionalEntity < Grape::Entity
        expose :mandatory, documentation: { type: String }
        expose :maybe, documentation: { type: String, "x-maybe" => "yes" }, if: ->(_, _) { false }
        expose :details, using: DetailEntity, merge: true
        expose :extras, using: DetailEntity, documentation: { is_array: true, type: DetailEntity }
      end

      def test_conditions_mark_nullable
        schema = Introspectors::EntityIntrospector.new(ConditionalEntity).build_schema

        refute_includes schema.required, "maybe"
        assert schema.properties["maybe"].nullable
        assert_equal "yes", schema.properties["maybe"].extensions["x-maybe"]
      end

      def test_merge_flattens_properties
        schema = Introspectors::EntityIntrospector.new(ConditionalEntity).build_schema

        assert_includes schema.properties.keys, "a"
        assert_includes schema.properties.keys, "b"
      end

      def test_array_using_with_entity
        schema = Introspectors::EntityIntrospector.new(ConditionalEntity).build_schema
        extras = schema.properties["extras"]

        assert_equal "array", extras.type
        assert_equal %w[a b], extras.items.properties.keys.sort
      end
    end
  end
end
