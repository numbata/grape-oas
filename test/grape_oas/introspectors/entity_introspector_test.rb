# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorTest < Minitest::Test
      # === Test Entities for basic property/ref tests ===
      class AddressEntity < Grape::Entity
        expose :city, documentation: { type: String }
      end

      class ProfileEntity < Grape::Entity
        expose :bio, documentation: { type: String, nullable: true }
      end

      class UserEntity < Grape::Entity
        expose :id, documentation: { type: Integer, desc: "User ID", nullable: true }
        expose :name, documentation: { type: String }
        expose :address, using: AddressEntity, documentation: { type: AddressEntity }
        expose :tags, documentation: { type: String, is_array: true, values: %w[a b] }
        expose :nickname, documentation: { type: String, example: "JJ", format: "nickname" }
        expose :profile, using: ProfileEntity, documentation: { type: ProfileEntity }
        def self.documentation
          { "x-entity-root" => "root-ext" }
        end
      end

      # === Test Entities for recursive/self-referential tests ===
      class RecursiveNode < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :children, using: self, documentation: { is_array: true }
      end

      # === Test Entities for conditional/merge tests ===
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

      # === Test Entity for Array class type ===
      class ArrayTypeEntity < Grape::Entity
        expose :tags, documentation: { type: Array }
        expose :numbers, documentation: { type: Array }
        expose :count, documentation: { type: Integer }
      end

      # === Basic property and reference tests ===

      def test_builds_properties_and_refs
        schema = Introspectors::EntityIntrospector.new(UserEntity).build_schema

        assert_equal "object", schema.type
        assert_equal "GrapeOAS::Introspectors::EntityIntrospectorTest::UserEntity", schema.canonical_name
        assert_equal %w[address id name nickname profile tags].sort, schema.properties.keys.sort

        id_schema = schema.properties["id"]

        assert_equal "integer", id_schema.type
        assert id_schema.nullable

        addr_schema = schema.properties["address"]

        assert_equal "object", addr_schema.type
        assert_equal "GrapeOAS::Introspectors::EntityIntrospectorTest::AddressEntity", addr_schema.canonical_name

        tags_schema = schema.properties["tags"]

        assert_equal "array", tags_schema.type
        assert_equal %w[a b], tags_schema.items.enum

        nick_schema = schema.properties["nickname"]

        assert_equal "nickname", nick_schema.format
        assert_equal "JJ", nick_schema.examples

        profile = schema.properties["profile"]

        assert_equal "object", profile.type
        assert_includes profile.properties.keys, "bio"

        assert_equal "root-ext", schema.extensions["x-entity-root"]
      end

      # === Recursive/self-referential entity tests ===

      def test_self_referential_entity_builds_with_ref
        schema = EntityIntrospector.new(RecursiveNode).build_schema

        # Builds top-level fields
        assert_equal %w[children id].sort, schema.properties.keys.sort

        children = schema.properties["children"]

        assert_equal "array", children.type

        items = children.items
        # Recursion should short-circuit to a ref-able schema, not inline infinitely
        assert_equal RecursiveNode.name, items.canonical_name
        refute_nil items.canonical_name
        # Ensure the entity still captured its own fields once
        assert_includes items.properties.keys, "id"
      end

      # === Required field behavior tests ===

      def test_unconditional_exposures_are_required_by_default
        schema = Introspectors::EntityIntrospector.new(ConditionalEntity).build_schema

        # Unconditional exposures are required by default (always present in output)
        assert_includes schema.required, "mandatory"
      end

      def test_conditional_exposures_are_not_required
        schema = Introspectors::EntityIntrospector.new(ConditionalEntity).build_schema

        # Conditional exposures are NOT required (may be absent from output)
        refute_includes schema.required, "maybe"
        # But they are NOT nullable - when present, the value is not null
        refute schema.properties["maybe"].nullable
        assert_equal "yes", schema.properties["maybe"].extensions["x-maybe"]
      end

      def test_explicit_required_false_is_respected
        entity_class = Class.new(Grape::Entity) do
          expose :always, documentation: { type: String }
          expose :optional, documentation: { type: String, required: false }
        end

        schema = Introspectors::EntityIntrospector.new(entity_class).build_schema

        assert_includes schema.required, "always"
        refute_includes schema.required, "optional"
      end

      def test_explicit_required_true_on_conditional_is_respected
        entity_class = Class.new(Grape::Entity) do
          # Even though conditional, explicit required: true takes precedence
          expose :forced, documentation: { type: String, required: true }, if: ->(_o, _opts) { true }
        end

        schema = Introspectors::EntityIntrospector.new(entity_class).build_schema

        assert_includes schema.required, "forced"
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

      # === Array class type tests ===

      def test_array_class_type_has_items
        # This tests the fix for the case/when bug where Array === Array returned false
        schema = Introspectors::EntityIntrospector.new(ArrayTypeEntity).build_schema

        tags = schema.properties["tags"]

        assert_equal "array", tags.type
        refute_nil tags.items, "Array type should have items schema"
        assert_equal "string", tags.items.type

        numbers = schema.properties["numbers"]

        assert_equal "array", numbers.type
        refute_nil numbers.items, "Array type should have items schema"
        assert_equal "string", numbers.items.type
      end
    end
  end
end
