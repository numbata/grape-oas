# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # End-to-end test: verifies that block-based nesting exposures produce correct
  # inline object schemas with preserved enum values, constraints, and metadata
  # through the full GrapeOAS.generate pipeline (introspection → export → JSON).
  class GenerateNestingExposureTest < Minitest::Test
    # ============================================================
    # Entity Definitions
    # ============================================================

    class StatusEntity < Grape::Entity
      expose :meta do
        expose :alignment, documentation: { type: String, values: %w[left center right] }
        expose :visible, documentation: { type: "Boolean" }
      end
    end

    class SlideEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :title, documentation: { type: String }
      expose :text_align do
        expose :horizontal, documentation: { type: String, values: %w[left center right] }
        expose :vertical, documentation: { type: String, values: %w[top center bottom] }
      end
      expose :size_offset, documentation: { type: Integer, minimum: -2, maximum: 2 }
    end

    # Duplicate-key nesting: same child key exposed twice inside a parent block.
    # Both branches get merged into one inline object schema.
    class DuplicateKeyEntity < Grape::Entity
      expose :container do
        expose :payload do
          expose :kind, documentation: { type: String, values: %w[image text] }
        end
        expose :payload do
          expose :url, documentation: { type: String }
        end
      end
    end

    # Deep nesting
    class DeepNestingEntity < Grape::Entity
      expose :a do
        expose :b do
          expose :c, documentation: { type: String, values: %w[x y z] }
        end
      end
    end

    class API < Grape::API
      format :json

      namespace :statuses do
        get entity: StatusEntity do
          {}
        end
      end

      namespace :slides do
        get entity: SlideEntity do
          {}
        end
      end

      namespace :duplicate do
        get entity: DuplicateKeyEntity do
          {}
        end
      end

      namespace :deep do
        get entity: DeepNestingEntity do
          {}
        end
      end
    end

    # ============================================================
    # Setup
    # ============================================================

    def setup
      @oas3 = GrapeOAS.generate(app: API, schema_type: :oas3)
      @oas2 = GrapeOAS.generate(app: API, schema_type: :oas2)
    end

    # ============================================================
    # OAS3: basic nesting produces inline object with enum
    # ============================================================

    def test_oas3_nesting_block_produces_object_schema
      meta = status_entity_schema(@oas3).dig("properties", "meta")

      assert_equal "object", meta["type"]
    end

    def test_oas3_nesting_block_child_enum_preserved
      meta = status_entity_schema(@oas3).dig("properties", "meta")
      alignment = meta.dig("properties", "alignment")

      assert_equal "string", alignment["type"]
      assert_equal %w[left center right], alignment["enum"]
    end

    def test_oas3_nesting_block_child_boolean_type
      meta = status_entity_schema(@oas3).dig("properties", "meta")
      visible = meta.dig("properties", "visible")

      assert_equal "boolean", visible["type"]
    end

    def test_oas3_nested_text_align_object
      props = slide_entity_schema(@oas3).dig("properties", "text_align")

      assert_equal "object", props["type"]
      assert_equal %w[left center right], props.dig("properties", "horizontal", "enum")
      assert_equal %w[top center bottom], props.dig("properties", "vertical", "enum")
    end

    def test_oas3_deep_nesting_preserves_enum
      schema = deep_nesting_entity_schema(@oas3)
      c = schema.dig("properties", "a", "properties", "b", "properties", "c")

      assert_equal "string", c["type"]
      assert_equal %w[x y z], c["enum"]
    end

    def test_oas3_duplicate_key_nesting_merges_properties
      schema = duplicate_key_entity_schema(@oas3)
      payload = schema.dig("properties", "container", "properties", "payload")

      assert_equal "object", payload["type"]
      # Properties from both branches are merged into one inline object
      assert_includes payload["properties"].keys, "kind"
      assert_includes payload["properties"].keys, "url"
    end

    def test_oas3_duplicate_key_nesting_unconditional_branches_are_required
      schema = duplicate_key_entity_schema(@oas3)
      container_required = schema.dig("properties", "container", "required") || []

      # Both branches are unconditional so payload is required
      assert_includes container_required, "payload"
    end

    # ============================================================
    # OAS2: same checks pass through OAS2 serialization
    # ============================================================

    def test_oas2_nesting_block_produces_object_schema
      meta = status_entity_schema(@oas2).dig("properties", "meta")

      assert_equal "object", meta["type"]
    end

    def test_oas2_nesting_block_child_enum_preserved
      meta = status_entity_schema(@oas2).dig("properties", "meta")
      alignment = meta.dig("properties", "alignment")

      assert_equal "string", alignment["type"]
      assert_equal %w[left center right], alignment["enum"]
    end

    private

    def find_component(schema, entity_class)
      components = schema.dig("components", "schemas") || schema["definitions"] || {}
      key = components.keys.find { |k| k.include?(entity_class.name.split("::").last) }
      components[key]
    end

    def status_entity_schema(schema)
      find_component(schema, StatusEntity)
    end

    def slide_entity_schema(schema)
      find_component(schema, SlideEntity)
    end

    def duplicate_key_entity_schema(schema)
      find_component(schema, DuplicateKeyEntity)
    end

    def deep_nesting_entity_schema(schema)
      find_component(schema, DeepNestingEntity)
    end
  end
end
