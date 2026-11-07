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

      class ExposureProcessorDescriptionScopeTest < Minitest::Test
        class ScopedImage < Grape::Entity
          expose :url, documentation: { type: String }
        end

        class ScopedPage < Grape::Entity
          expose :hero, using: ScopedImage, documentation: { desc: "Hero image" }
          expose :logo, using: ScopedImage, documentation: { desc: "Page logo" }
          expose :gallery, using: ScopedImage, documentation: { desc: "Gallery", is_array: true }
        end

        def test_descriptions_stay_local_to_each_property
          schema = EntityIntrospector.new(ScopedPage).build_schema
          hero = schema.properties["hero"]
          logo = schema.properties["logo"]
          gallery = schema.properties["gallery"]

          assert_equal "Hero image", hero.description
          assert_equal "Page logo", logo.description
          assert_nil hero.all_of.first.description
          assert_same hero.all_of.first, logo.all_of.first
          assert_equal "Gallery", gallery.description
          assert_nil gallery.items.description
        end

        class StrictScopedPage < Grape::Entity
          expose :hero, using: ScopedImage, documentation: { desc: "Hero image", additional_properties: false }
          expose :logo, using: ScopedImage, documentation: { desc: "Page logo" }
        end

        def test_described_property_keeps_additional_properties_on_its_own_schema
          schema = EntityIntrospector.new(StrictScopedPage).build_schema
          hero = schema.properties["hero"]
          logo = schema.properties["logo"]

          assert_equal "Hero image", hero.description
          assert_same false, hero.additional_properties
          assert_nil hero.canonical_name
          assert_nil logo.all_of.first.additional_properties
          assert_same false, GrapeOAS::Exporter::OAS3::Schema.new(hero).build["additionalProperties"]
        end

        class SpelledScopedPage < Grape::Entity
          expose :gallery, using: ScopedImage, documentation: { desc: "Gallery", is_array: true }
          expose :photos, documentation: { type: ScopedImage, is_array: true, desc: "Photos" }
        end

        def test_described_entity_array_spellings_share_item_shape
          schema = EntityIntrospector.new(SpelledScopedPage).build_schema

          { "gallery" => "Gallery", "photos" => "Photos" }.each do |name, desc|
            prop = schema.properties[name]

            assert_equal desc, prop.description
            assert prop.items.canonical_name, "#{name} items must be the bare entity schema"
            assert_nil prop.items.all_of, "#{name} items must not be wrapped"
            assert_nil prop.items.description
          end
        end

        class NamedScopedPage < Grape::Entity
          expose :photos, documentation: { type: ScopedImage.name, is_array: true, desc: "Photos" }
        end

        def test_described_entity_array_named_by_string_keeps_description_off_shared_items
          prop = EntityIntrospector.new(NamedScopedPage).build_schema.properties["photos"]

          assert_equal "Photos", prop.description
          assert prop.items.canonical_name, "items must be the bare entity schema"
          assert_nil prop.items.description
        end

        def test_object_keywords_do_not_mutate_the_shared_entity_schema
          schema = EntityIntrospector.new(StrictScopedPage).build_schema
          shared = schema.properties["logo"].all_of.first

          assert shared.canonical_name
          assert_nil shared.additional_properties
          refute_same shared, schema.properties["hero"]
        end

        def test_each_object_keyword_on_described_property_stays_on_its_own_schema
          {
            additional_properties: false,
            unevaluated_properties: false,
            defs: { "Note" => { type: "string" } },
            :$defs => { "Note" => { type: "string" } }
          }.each do |key, value|
            klass = Class.new(Grape::Entity) do
              expose :hero, using: ScopedImage, documentation: { desc: "Hero image", key => value }
              expose :logo, using: ScopedImage, documentation: { desc: "Page logo" }
            end
            schema = EntityIntrospector.new(klass).build_schema
            hero = schema.properties["hero"]
            shared = schema.properties["logo"].all_of.first
            attr = key.to_s.delete_prefix("$")

            assert_equal value, hero.public_send(attr), "#{key} must stay on the described property"
            assert_nil hero.canonical_name, "#{key} must inline the described property"
            assert_nil hero.all_of, "#{key} must not wrap the described property in allOf"
            assert shared.canonical_name, "#{key} must not clear the shared schema name"
            refute_equal value, shared.public_send(attr), "#{key} must not reach the shared schema"
          end
        end

        class NilKeywordScopedPage < Grape::Entity
          expose :hero, using: ScopedImage, documentation: { desc: "Hero image", additional_properties: nil }
        end

        def test_nil_object_keyword_does_not_inline_described_property
          schema = EntityIntrospector.new(NilKeywordScopedPage).build_schema
          hero = schema.properties["hero"]

          assert_equal "Hero image", hero.description
          assert_nil hero.canonical_name
          refute_nil hero.all_of.first.canonical_name
          assert_nil hero.additional_properties
        end
      end
    end
  end
end
