# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      class ExposureProcessorTest < Minitest::Test
        # A shared entity used via `using:` — its schema will be cached/shared
        # (canonical_name set) once registered through the introspector pipeline.
        class StatusEntity < Grape::Entity
          expose :code, documentation: { type: String }
        end

        # === Enum on top-level cached entity schema is applied via dup, not silent skip ===
        # using: must be a native Grape option (not inside documentation:) so that
        # opts[:using] is set and the entity schema (with canonical_name) is returned.

        class TopLevelEnumEntity < Grape::Entity
          expose :status, using: StatusEntity, documentation: { values: %w[active inactive] }
        end

        def test_enum_on_cached_entity_schema_is_applied_to_dup
          log = capture_grape_oas_log do
            @schema = EntityIntrospector.new(TopLevelEnumEntity).build_schema
          end

          status_prop = @schema.properties["status"]

          refute_nil status_prop, "expected 'status' property to exist"
          assert_equal %w[active inactive], status_prop.enum,
                       "enum must be applied even when the base schema is a cached entity ref"
          assert_match(/Duplicating cached schema/, log)
          assert_match(/StatusEntity/, log)
          assert_match(/active/, log)
        end

        # === Enum on array-wrapped cached entity schema is applied via items dup ===

        class ArrayEnumEntity < Grape::Entity
          expose :statuses, using: [StatusEntity], documentation: { values: %w[pending done] }
        end

        def test_enum_on_array_of_cached_entity_items_is_applied_to_dup
          log = capture_grape_oas_log do
            @schema = EntityIntrospector.new(ArrayEnumEntity).build_schema
          end

          statuses_prop = @schema.properties["statuses"]

          refute_nil statuses_prop, "expected 'statuses' property to exist"
          assert_equal "array", statuses_prop.type
          refute_nil statuses_prop.items, "expected items to be set"
          assert_equal %w[pending done], statuses_prop.items.enum,
                       "enum must be applied to items even when items schema is a cached entity ref"
          assert_match(/Duplicating cached schema/, log)
          assert_match(/StatusEntity/, log)
          assert_match(/pending/, log)
        end

        # === Cached base schema is not mutated by the dup path ===

        def test_cached_entity_schema_is_not_mutated
          # Introspect twice; the second introspection's enum must not bleed into the
          # cached schema used by the first (or any subsequent) introspection.
          schema1 = nil
          schema2 = nil

          capture_grape_oas_log do
            schema1 = EntityIntrospector.new(TopLevelEnumEntity).build_schema
            schema2 = EntityIntrospector.new(TopLevelEnumEntity).build_schema
          end

          # Both should have enum set (each gets its own dup).
          assert_equal %w[active inactive], schema1.properties["status"].enum
          assert_equal %w[active inactive], schema2.properties["status"].enum

          # The two property schemas must be different objects (each a fresh dup).
          refute_same schema1.properties["status"], schema2.properties["status"]
        end
      end

      # Unit tests for apply_enum_to_schema in isolation
      class ExposureProcessorApplyEnumTest < Minitest::Test
        def setup
          @processor = ExposureProcessor.new(Class.new, stack: [], registry: {})
        end

        # === Top-level cached schema ===

        def test_cached_schema_returns_dup_with_enum_and_cleared_canonical_name
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "MyEntity",
          )
          result = @processor.send(:apply_enum_to_schema, original, %w[a b])

          refute_same original, result
          assert_equal %w[a b], result.enum
          assert_nil result.canonical_name
        end

        def test_cached_schema_does_not_mutate_original
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "MyEntity",
          )
          @processor.send(:apply_enum_to_schema, original, %w[a b])

          assert_nil original.enum
          assert_equal "MyEntity", original.canonical_name
        end

        def test_cached_schema_emits_warning
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "MyEntity",
          )
          output = capture_grape_oas_log do
            @processor.send(:apply_enum_to_schema, original, %w[a b])
          end

          assert_includes output, "Duplicating cached schema 'MyEntity'"
          assert_includes output, '["a", "b"]'
        end

        # === Array with cached items ===

        def test_array_cached_items_returns_dup_with_items_enum
          items = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "ItemEntity",
          )
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY, items: items,
          )
          result = @processor.send(:apply_enum_to_schema, original, %w[x y])

          refute_same original, result
          refute_same items, result.items
          assert_equal %w[x y], result.items.enum
          assert_nil result.items.canonical_name
        end

        def test_array_cached_items_does_not_mutate_original
          items = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "ItemEntity",
          )
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY, items: items,
          )
          @processor.send(:apply_enum_to_schema, original, %w[x y])

          assert_nil items.enum
          assert_equal "ItemEntity", items.canonical_name
          assert_same items, original.items
        end

        def test_array_cached_items_emits_warning
          items = ApiModel::Schema.new(
            type: Constants::SchemaTypes::STRING, canonical_name: "ItemEntity",
          )
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY, items: items,
          )
          output = capture_grape_oas_log do
            @processor.send(:apply_enum_to_schema, original, %w[x y])
          end

          assert_includes output, "Duplicating cached schema 'ItemEntity'"
          assert_includes output, '["x", "y"]'
        end

        # === Dup isolation — mutating the dup must not corrupt the cached original ===

        def test_cached_schema_dup_properties_are_isolated_from_original
          child = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          original = ApiModel::Schema.new(
            type: Constants::SchemaTypes::OBJECT, canonical_name: "CachedEntity",
          )
          original.add_property("name", child, required: true)

          result = nil
          capture_grape_oas_log do
            result = @processor.send(:apply_enum_to_schema, original, %w[a b])
          end

          # Mutate the dup
          result.add_property("extra", ApiModel::Schema.new(type: Constants::SchemaTypes::INTEGER), required: true)

          refute_includes original.properties.keys, "extra",
                          "adding a property to the duped schema must not mutate the cached original"
          refute_includes original.required, "extra",
                          "adding a required field to the duped schema must not mutate the cached original"
          assert_equal 1, original.properties.size
          assert_equal ["name"], original.required
        end

        # === Non-cached top-level ===

        def test_non_cached_schema_applies_enum_in_place
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          result = @processor.send(:apply_enum_to_schema, schema, %w[a b])

          assert_same schema, result
          assert_equal %w[a b], schema.enum
        end

        # === Non-cached array ===

        def test_non_cached_array_applies_enum_to_items_in_place
          items = ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          schema = ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY, items: items,
          )
          result = @processor.send(:apply_enum_to_schema, schema, %w[a b])

          assert_same schema, result
          assert_equal %w[a b], items.enum
        end
      end
    end
  end
end
