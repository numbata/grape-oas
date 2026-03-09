# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    # Tests for block-based nesting exposures (NestingExposure) in entity introspection.
    # These verify that `expose :foo do ... end` patterns produce inline object schemas
    # with child properties and their enum values preserved.
    class EntityIntrospectorNestingExposureTest < Minitest::Test
      # === Basic block-based nesting with enum values ===

      class TextAlignmentEntity < Grape::Entity
        expose :label, documentation: { type: String }
        expose :textAlignment do
          expose :textHorizontalAlign, documentation: { type: String, values: %w[left center right] }
          expose :textVerticalAlign, documentation: { type: String, values: %w[top center bottom] }
        end
      end

      def test_nesting_exposure_builds_inline_object_with_properties
        schema = EntityIntrospector.new(TextAlignmentEntity).build_schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "label"
        assert_includes schema.properties.keys, "textAlignment"

        ta = schema.properties["textAlignment"]

        assert_equal "object", ta.type
        assert_includes ta.properties.keys, "textHorizontalAlign"
        assert_includes ta.properties.keys, "textVerticalAlign"
      end

      def test_nesting_exposure_preserves_enum_values_on_children
        schema = EntityIntrospector.new(TextAlignmentEntity).build_schema

        ta = schema.properties["textAlignment"]
        h_align = ta.properties["textHorizontalAlign"]
        v_align = ta.properties["textVerticalAlign"]

        assert_equal %w[left center right], h_align.enum
        assert_equal %w[top center bottom], v_align.enum
      end

      # === Deeply nested blocks (2+ levels) ===

      class DeepNestingEntity < Grape::Entity
        expose :config do
          expose :display do
            expose :mode, documentation: { type: String, values: %w[compact expanded] }
            expose :columns, documentation: { type: Integer }
          end
          expose :name, documentation: { type: String }
        end
      end

      def test_deeply_nested_blocks
        schema = EntityIntrospector.new(DeepNestingEntity).build_schema

        config = schema.properties["config"]

        assert_equal "object", config.type
        assert_includes config.properties.keys, "display"
        assert_includes config.properties.keys, "name"

        display = config.properties["display"]

        assert_equal "object", display.type
        assert_includes display.properties.keys, "mode"
        assert_includes display.properties.keys, "columns"

        assert_equal %w[compact expanded], display.properties["mode"].enum
        assert_equal "integer", display.properties["columns"].type
      end

      # === Nesting exposure with documentation on the parent ===

      class DocumentedNestingEntity < Grape::Entity
        expose :settings, documentation: { desc: "User settings", nullable: true } do
          expose :theme, documentation: { type: String, values: %w[light dark] }
        end
      end

      def test_nesting_exposure_applies_parent_documentation
        schema = EntityIntrospector.new(DocumentedNestingEntity).build_schema

        settings = schema.properties["settings"]

        assert_equal "object", settings.type
        assert_equal "User settings", settings.description
        assert settings.nullable
        assert_equal %w[light dark], settings.properties["theme"].enum
      end

      # === Nesting exposure wrapping an array ===

      class ArrayNestingEntity < Grape::Entity
        expose :items, documentation: { is_array: true } do
          expose :id, documentation: { type: Integer }
          expose :status, documentation: { type: String, values: %w[active inactive] }
        end
      end

      def test_nesting_exposure_with_array_wrapper
        schema = EntityIntrospector.new(ArrayNestingEntity).build_schema

        items = schema.properties["items"]

        assert_equal "array", items.type
        assert_equal "object", items.items.type
        assert_includes items.items.properties.keys, "id"
        assert_includes items.items.properties.keys, "status"
        assert_equal %w[active inactive], items.items.properties["status"].enum
      end

      # === Mixed: nesting exposure with using: entity child ===

      class InnerEntity < Grape::Entity
        expose :value, documentation: { type: String }
      end

      class MixedNestingEntity < Grape::Entity
        expose :wrapper do
          expose :simple, documentation: { type: String, values: %w[a b] }
          expose :nested, using: InnerEntity, documentation: { type: InnerEntity }
        end
      end

      def test_mixed_nesting_with_entity_child
        schema = EntityIntrospector.new(MixedNestingEntity).build_schema

        wrapper = schema.properties["wrapper"]

        assert_equal "object", wrapper.type
        assert_equal %w[a b], wrapper.properties["simple"].enum

        nested = wrapper.properties["nested"]

        assert_equal "object", nested.type
        assert_includes nested.properties.keys, "value"
      end

      # === Duplicate-key nested exposures (conditional branches) ===

      class DuplicateKeyNestingEntity < Grape::Entity
        expose :meta do
          expose :info do
            expose :alpha, documentation: { type: String }
          end
          expose :info do
            expose :beta, documentation: { type: Integer }
          end
        end
      end

      def test_duplicate_key_children_merge_object_properties
        schema = EntityIntrospector.new(DuplicateKeyNestingEntity).build_schema

        meta = schema.properties["meta"]

        assert_equal "object", meta.type

        info = meta.properties["info"]

        assert_equal "object", info.type
        # Both branches should be merged — alpha from first, beta from second
        assert_includes info.properties.keys, "alpha"
        assert_includes info.properties.keys, "beta"
        # Branch-specific fields are NOT required (only shared fields would be)
        refute_includes info.required, "alpha"
        refute_includes info.required, "beta"
      end

      # === Deep duplicate-key merge (recursive) ===

      class DeepDuplicateKeyEntity < Grape::Entity
        expose :meta do
          expose :info do
            expose :details do
              expose :x, documentation: { type: String }
            end
          end
          expose :info do
            expose :details do
              expose :y, documentation: { type: Integer }
            end
          end
        end
      end

      def test_deep_duplicate_key_merge_preserves_nested_properties
        schema = EntityIntrospector.new(DeepDuplicateKeyEntity).build_schema

        details = schema.properties["meta"].properties["info"].properties["details"]

        assert_equal "object", details.type
        assert_includes details.properties.keys, "x"
        assert_includes details.properties.keys, "y"
      end

      # === Conditional exposure inside nesting block ===

      class ConditionalNestingEntity < Grape::Entity
        expose :data do
          expose :always, documentation: { type: String }
          expose :sometimes, documentation: { type: String, values: %w[x y] }, if: { type: :full }
        end
      end

      def test_conditional_child_in_nesting_block
        schema = EntityIntrospector.new(ConditionalNestingEntity).build_schema

        data = schema.properties["data"]

        assert_equal "object", data.type
        assert_includes data.properties.keys, "always"
        assert_includes data.properties.keys, "sometimes"
        assert_equal %w[x y], data.properties["sometimes"].enum

        # Conditional child should not be required
        refute_includes data.required, "sometimes"
        assert_includes data.required, "always"
      end

      # === Duplicate-key nesting with branch metadata (desc, nullable) ===

      class MetadataBranchEntity < Grape::Entity
        expose :meta do
          expose :info, documentation: { desc: "First branch" } do
            expose :alpha, documentation: { type: String }
          end
          expose :info, documentation: { desc: "Second branch", nullable: true } do
            expose :beta, documentation: { type: Integer }
          end
        end
      end

      def test_duplicate_key_merge_preserves_branch_metadata
        schema = EntityIntrospector.new(MetadataBranchEntity).build_schema

        info = schema.properties["meta"].properties["info"]

        assert_equal "object", info.type
        assert_includes info.properties.keys, "alpha"
        assert_includes info.properties.keys, "beta"
        # Last branch wins for scalar metadata
        assert_equal "Second branch", info.description
        assert info.nullable
      end
    end
  end
end
