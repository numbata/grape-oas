# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorRecursiveTest < Minitest::Test
      class RecursiveNode < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :children, using: self, documentation: { is_array: true }
      end

      def test_self_referential_entity_builds_with_ref
        schema = EntityIntrospector.new(RecursiveNode).build_schema

        # Builds top-level fields
        assert_equal %w[children id].sort, schema.properties.keys.sort

        children = schema.properties["children"]

        assert_equal "array", children.type

        items = children.items
        # Recursion should short‑circuit to a ref-able schema, not inline infinitely
        assert_equal RecursiveNode.name, items.canonical_name
        refute_nil items.canonical_name
        # Ensure the entity still captured its own fields once
        assert_includes items.properties.keys, "id"
      end
    end
  end
end
