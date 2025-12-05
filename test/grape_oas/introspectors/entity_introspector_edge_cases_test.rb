# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorEdgeCasesTest < Minitest::Test
      # === Empty entity (grape-swagger #962) ===

      class EmptyEntity < Grape::Entity
        # No exposures - should produce empty properties
      end

      def test_empty_entity_produces_empty_properties
        schema = EntityIntrospector.new(EmptyEntity).build_schema

        assert_equal "object", schema.type
        assert_empty schema.properties
      end

      # === Entity with all hidden properties ===

      class HiddenPropertiesEntity < Grape::Entity
        expose :visible, documentation: { type: String }
        expose :hidden_field, documentation: { type: String, hidden: true }
      end

      def test_hidden_property_handling
        schema = EntityIntrospector.new(HiddenPropertiesEntity).build_schema

        # Both properties should be in the schema (hidden is for swagger-ui, not schema)
        assert_includes schema.properties.keys, "visible"
        assert_includes schema.properties.keys, "hidden_field"
      end

      # === Entity with string type references (grape-swagger #427) ===

      class ReferencedEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :name, documentation: { type: String }
      end

      class EntityWithStringRef < Grape::Entity
        expose :data, documentation: { type: "GrapeOAS::Introspectors::EntityIntrospectorEdgeCasesTest::ReferencedEntity" }
      end

      def test_entity_with_string_type_reference
        schema = EntityIntrospector.new(EntityWithStringRef).build_schema

        assert_includes schema.properties.keys, "data"
        # String type reference should be resolved to an object
        data = schema.properties["data"]

        assert_equal "object", data.type
      end

      # === Entity with extension properties (x-*) ===

      class ExtensionEntity < Grape::Entity
        expose :status, documentation: {
          type: String,
          "x-nullable" => true,
          "x-deprecated" => "Use 'state' instead"
        }
        expose :state, documentation: { type: String }
      end

      def test_entity_with_extension_properties
        schema = EntityIntrospector.new(ExtensionEntity).build_schema

        status = schema.properties["status"]
        # Extensions should be preserved
        assert status.extensions["x-nullable"]
        assert_equal "Use 'state' instead", status.extensions["x-deprecated"]
      end

      # === Entity with conditional exposures ===

      class ConditionalExposureEntity < Grape::Entity
        expose :always, documentation: { type: String }
        expose :sometimes, documentation: { type: String }, if: ->(obj, _opts) { obj.respond_to?(:show_sometimes?) }
        expose :never, documentation: { type: String }, unless: ->(_obj, _opts) { true }
      end

      def test_conditional_exposures_not_required_but_not_nullable
        schema = EntityIntrospector.new(ConditionalExposureEntity).build_schema

        # Conditional exposures are NOT required (may be absent from output)
        # but they are NOT nullable - when present, the value is not null
        sometimes = schema.properties["sometimes"]
        never = schema.properties["never"]

        refute sometimes.nullable, "Conditional 'if' exposure should NOT be nullable"
        refute never.nullable, "Conditional 'unless' exposure should NOT be nullable"

        refute_includes schema.required, "sometimes"
        refute_includes schema.required, "never"
      end

      # === Entity with merge: true ===

      class MergedChildEntity < Grape::Entity
        expose :child_field, documentation: { type: String }
        expose :shared_field, documentation: { type: Integer }
      end

      class ParentWithMergedChild < Grape::Entity
        expose :parent_field, documentation: { type: String }
        expose :child, using: MergedChildEntity, merge: true
      end

      def test_merge_true_flattens_child_properties
        schema = EntityIntrospector.new(ParentWithMergedChild).build_schema

        # Child properties should be merged into parent
        assert_includes schema.properties.keys, "parent_field"
        assert_includes schema.properties.keys, "child_field"
        assert_includes schema.properties.keys, "shared_field"
      end

      # === Entity with array of entities ===

      class ItemEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :name, documentation: { type: String }
      end

      class ContainerEntity < Grape::Entity
        expose :title, documentation: { type: String }
        expose :items, using: ItemEntity, documentation: { type: ItemEntity, is_array: true }
      end

      def test_array_of_entities_with_is_array_flag
        schema = EntityIntrospector.new(ContainerEntity).build_schema

        items = schema.properties["items"]

        assert_equal "array", items.type
        assert_equal "object", items.items.type
        assert_includes items.items.properties.keys, "id"
        assert_includes items.items.properties.keys, "name"
      end

      # === Entity with format specification ===

      class FormattedEntity < Grape::Entity
        expose :id, documentation: { type: String, format: "uuid" }
        expose :email, documentation: { type: String, format: "email" }
        expose :created_at, documentation: { type: String, format: "date-time" }
        expose :website, documentation: { type: String, format: "uri" }
      end

      def test_entity_with_format_specifications
        schema = EntityIntrospector.new(FormattedEntity).build_schema

        assert_equal "uuid", schema.properties["id"].format
        assert_equal "email", schema.properties["email"].format
        assert_equal "date-time", schema.properties["created_at"].format
        assert_equal "uri", schema.properties["website"].format
      end

      # === Entity with example values ===

      class ExampleEntity < Grape::Entity
        expose :name, documentation: { type: String, example: "John Doe" }
        expose :age, documentation: { type: Integer, example: 30 }
      end

      def test_entity_with_example_values
        schema = EntityIntrospector.new(ExampleEntity).build_schema

        assert_equal "John Doe", schema.properties["name"].examples
        assert_equal 30, schema.properties["age"].examples
      end

      # === Entity with enum values ===

      class EnumEntity < Grape::Entity
        expose :status, documentation: { type: String, values: %w[pending active completed] }
        expose :priority, documentation: { type: Integer, values: [1, 2, 3] }
      end

      def test_entity_with_enum_values
        schema = EntityIntrospector.new(EnumEntity).build_schema

        assert_equal %w[pending active completed], schema.properties["status"].enum
        assert_equal [1, 2, 3], schema.properties["priority"].enum
      end

      # === Entity with min/max constraints ===

      class ConstrainedEntity < Grape::Entity
        expose :count, documentation: { type: Integer, minimum: 0, maximum: 100 }
        expose :name, documentation: { type: String, min_length: 1, max_length: 255 }
      end

      def test_entity_with_constraints
        schema = EntityIntrospector.new(ConstrainedEntity).build_schema

        count = schema.properties["count"]

        assert_equal 0, count.minimum
        assert_equal 100, count.maximum

        name = schema.properties["name"]

        assert_equal 1, name.min_length
        assert_equal 255, name.max_length
      end

      # === Entity inheritance ===

      class BaseEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :created_at, documentation: { type: String }
      end

      class DerivedEntity < BaseEntity
        expose :name, documentation: { type: String }
        expose :description, documentation: { type: String }
      end

      def test_entity_inheritance
        schema = EntityIntrospector.new(DerivedEntity).build_schema

        # Should have both parent and child properties
        assert_includes schema.properties.keys, "id"
        assert_includes schema.properties.keys, "created_at"
        assert_includes schema.properties.keys, "name"
        assert_includes schema.properties.keys, "description"
      end

      # === Nested entity with same name in different context ===

      class OuterEntity < Grape::Entity
        class InnerEntity < Grape::Entity
          expose :inner_value, documentation: { type: String }
        end

        expose :name, documentation: { type: String }
        expose :inner, using: InnerEntity, documentation: { type: InnerEntity }
      end

      def test_nested_entity_class
        schema = EntityIntrospector.new(OuterEntity).build_schema

        assert_includes schema.properties.keys, "name"
        assert_includes schema.properties.keys, "inner"

        inner = schema.properties["inner"]

        assert_equal "object", inner.type
        assert_includes inner.properties.keys, "inner_value"
      end
    end
  end
end
