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

      # === Entity with array-type enum (applied to items, not array itself) ===

      class ArrayEnumEntity < Grape::Entity
        expose :tags, documentation: { type: Array, values: %w[red green blue] }
      end

      def test_array_type_enum_applied_to_items
        schema = EntityIntrospector.new(ArrayEnumEntity).build_schema

        tags = schema.properties["tags"]

        assert_equal "array", tags.type
        assert_nil tags.enum
        assert_equal %w[red green blue], tags.items.enum
      end

      # === Entity with false-only enum ===

      class FalseOnlyEnumEntity < Grape::Entity
        expose :locked, documentation: { type: "Boolean", values: [false] }
      end

      def test_entity_with_false_only_enum
        schema = EntityIntrospector.new(FalseOnlyEnumEntity).build_schema

        assert_equal [false], schema.properties["locked"].enum
      end

      # === Numeric range on non-numeric type is skipped ===

      class NumericRangeOnStringEntity < Grape::Entity
        expose :code, documentation: { type: String, values: 1..5 }
      end

      def test_numeric_range_on_string_type_does_not_set_min_max
        log = capture_grape_oas_log do
          @schema = EntityIntrospector.new(NumericRangeOnStringEntity).build_schema
        end

        prop = @schema.properties["code"]

        assert_equal "string", prop.type
        assert_nil prop.minimum
        assert_nil prop.maximum
        assert_match(/Numeric range.*ignored on non-numeric/, log)
      end

      # === Entity with Range values (numeric) ===

      class RangeEntity < Grape::Entity
        expose :offset, documentation: { type: Integer, values: -2..2 }
        expose :score, documentation: { type: Integer, values: 0..100 }
      end

      def test_entity_with_numeric_range_values
        schema = EntityIntrospector.new(RangeEntity).build_schema

        offset = schema.properties["offset"]

        assert_equal(-2, offset.minimum)
        assert_equal 2, offset.maximum
        assert_nil offset.enum

        score = schema.properties["score"]

        assert_equal 0, score.minimum
        assert_equal 100, score.maximum
        assert_nil score.enum
      end

      # === Entity with exclusive numeric Range ===

      class ExclusiveRangeEntity < Grape::Entity
        expose :index, documentation: { type: Integer, values: 0...10 }
      end

      def test_entity_with_exclusive_numeric_range
        schema = EntityIntrospector.new(ExclusiveRangeEntity).build_schema

        index = schema.properties["index"]

        assert_equal 0, index.minimum
        assert_equal 10, index.maximum
        assert index.exclusive_maximum
      end

      # === Entity with non-numeric Range values ===

      class LetterRangeEntity < Grape::Entity
        expose :grade, documentation: { type: String, values: "a".."f" }
      end

      def test_entity_with_non_numeric_range_values
        schema = EntityIntrospector.new(LetterRangeEntity).build_schema

        assert_equal %w[a b c d e f], schema.properties["grade"].enum
      end

      # === Entity with wide non-numeric Range (capped expansion) ===

      class WideStringRangeEntity < Grape::Entity
        expose :code, documentation: { type: String, values: "a".."zzzzzz" }
      end

      def test_entity_with_wide_string_range_does_not_expand
        schema = EntityIntrospector.new(WideStringRangeEntity).build_schema

        # Range too wide (>100 elements) — should be silently skipped, not OOM
        assert_nil schema.properties["code"].enum
      end

      # === Entity with descending numeric Range (e.g. 10..1) ===

      class DescendingNumericRangeEntity < Grape::Entity
        expose :level, documentation: { type: Integer, values: 10..1 }
      end

      def test_entity_with_descending_numeric_range_is_skipped
        schema = EntityIntrospector.new(DescendingNumericRangeEntity).build_schema

        assert_nil schema.properties["level"].minimum
        assert_nil schema.properties["level"].maximum
      end

      # === Entity with descending string Range (e.g. "z".."a") ===

      class DescendingStringRangeEntity < Grape::Entity
        expose :letter, documentation: { type: String, values: "z".."a" }
      end

      def test_entity_with_descending_string_range_is_skipped
        schema = EntityIntrospector.new(DescendingStringRangeEntity).build_schema

        assert_nil schema.properties["letter"].enum
      end

      # === Entity with non-discrete Range (e.g. Time) does not crash ===

      class NonDiscreteRangeEntity < Grape::Entity
        expose :window, documentation: { type: String, values: Time.new(2024, 1, 1)..Time.new(2024, 12, 31) }
      end

      def test_entity_with_non_discrete_range_does_not_crash
        schema = EntityIntrospector.new(NonDiscreteRangeEntity).build_schema

        # Should not raise, and enum should be nil since Time range can't be expanded
        assert_nil schema.properties["window"].enum
      end

      # === Entity with Set values ===

      class SetEntity < Grape::Entity
        expose :color, documentation: { type: String, values: Set.new(%w[red green blue]) }
      end

      def test_entity_with_set_values
        schema = EntityIntrospector.new(SetEntity).build_schema

        assert_instance_of Array, schema.properties["color"].enum
        assert_equal 3, schema.properties["color"].enum.length
        assert_includes schema.properties["color"].enum, "red"
        assert_includes schema.properties["color"].enum, "green"
        assert_includes schema.properties["color"].enum, "blue"
      end

      # === Entity with Proc values (arity 0) ===

      class ProcEntity < Grape::Entity
        expose :status, documentation: { type: String, values: -> { %w[open closed] } }
      end

      def test_entity_with_arity_zero_proc_values
        schema = EntityIntrospector.new(ProcEntity).build_schema

        assert_equal %w[open closed], schema.properties["status"].enum
      end

      # === Entity with Proc values (arity > 0, validator) ===

      class ValidatorProcEntity < Grape::Entity
        expose :code, documentation: { type: String, values: ->(v) { v.match?(/^[A-Z]+$/) } }
      end

      def test_entity_with_validator_proc_skips_enum
        schema = EntityIntrospector.new(ValidatorProcEntity).build_schema

        assert_nil schema.properties["code"].enum
      end

      # === Entity with callable object without arity (e.g. custom validator class) ===

      CallableValidator = Class.new do
        def self.call(value) # rubocop:disable Naming/PredicateMethod
          value.to_s.length.positive?
        end
      end

      class CallableValidatorEntity < Grape::Entity
        expose :code, documentation: { type: String, values: CallableValidator }
      end

      def test_entity_with_callable_without_arity_does_not_crash
        schema = EntityIntrospector.new(CallableValidatorEntity).build_schema

        assert_nil schema.properties["code"].enum
      end

      # === Entity with optional-arg validator proc (arity 0 but not enum) ===

      class OptionalArgValidatorEntity < Grape::Entity
        expose :code, documentation: { type: String, values: proc { |v = nil| v.to_s.length < 10 } }
      end

      def test_entity_with_optional_arg_validator_proc_skips_enum
        schema = EntityIntrospector.new(OptionalArgValidatorEntity).build_schema

        assert_nil schema.properties["code"].enum
      end

      # === Explicit maximum overrides range-derived exclusive_maximum ===

      class ExplicitMaxOverrideEntity < Grape::Entity
        expose :score, documentation: { type: Integer, values: 0...10, maximum: 5 }
      end

      def test_explicit_maximum_clears_exclusive_maximum
        schema = EntityIntrospector.new(ExplicitMaxOverrideEntity).build_schema

        prop = schema.properties["score"]

        assert_equal 0, prop.minimum
        assert_equal 5, prop.maximum
        assert_nil prop.exclusive_maximum
      end

      # === Entity with values on using: reference (canonical_name guard) ===

      class SimpleRefEntity < Grape::Entity
        expose :name, documentation: { type: String }
      end

      class ParentWithValuesOnRefEntity < Grape::Entity
        expose :child, using: SimpleRefEntity, documentation: { type: SimpleRefEntity, values: %w[should not appear] }
      end

      def test_entity_values_on_using_ref_applies_enum_via_dup
        schema = nil
        log = capture_grape_oas_log do
          schema = EntityIntrospector.new(ParentWithValuesOnRefEntity).build_schema
        end

        child = schema.properties["child"]

        # enum is now applied to a dup of the cached schema, not silently dropped
        assert_equal %w[should not appear], child.enum

        # the cached SimpleRefEntity schema itself must not be mutated
        cached = EntityIntrospector.new(SimpleRefEntity).build_schema

        assert_nil cached.enum, "cached schema must not be mutated"

        # a warning must be emitted naming the entity
        assert_match(/Duplicating cached schema/, log)
        assert_match(/SimpleRefEntity/, log)
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

      # === Entity with :description field (naming collision) ===

      class EntityWithDescriptionField < Grape::Entity
        expose :title, documentation: { type: String }
        expose :description, documentation: { type: String, desc: "A text description" }
      end

      def test_description_field_does_not_leak_as_entity_description
        schema = EntityIntrospector.new(EntityWithDescriptionField).build_schema

        # The entity-level description must be nil (not the Hash for the :description field)
        assert_nil schema.description, "Entity description should be nil, not field documentation Hash"

        # The :description field should still appear as a property
        assert_includes schema.properties.keys, "description"
        assert_equal "string", schema.properties["description"].type
      end

      # === PropertyExtractor.extract_description unit tests ===

      def test_extract_description_returns_string_description
        doc = { description: "A string description" }

        assert_equal "A string description",
                     EntityIntrospectorSupport::PropertyExtractor.extract_description(doc)
      end

      def test_extract_description_returns_nil_for_hash_description
        doc = { description: { type: String, desc: "field docs" } }

        assert_nil EntityIntrospectorSupport::PropertyExtractor.extract_description(doc)
      end

      def test_extract_description_falls_back_to_desc_key
        doc = { desc: "Fallback description" }

        assert_equal "Fallback description",
                     EntityIntrospectorSupport::PropertyExtractor.extract_description(doc)
      end

      def test_extract_description_returns_nil_when_no_description
        doc = { type: String }

        assert_nil EntityIntrospectorSupport::PropertyExtractor.extract_description(doc)
      end

      # === Entity exposure values: Range and [false] ===

      class RangeValuesEntity < Grape::Entity
        expose :level, documentation: { type: Integer, values: 1..5 }
        expose :flag, documentation: { type: "boolean", values: [false] }
      end

      def test_entity_exposure_range_values_apply_min_max
        schema = EntityIntrospector.new(RangeValuesEntity).build_schema
        level = schema.properties["level"]

        refute_nil level
        assert_equal 1, level.minimum
        assert_equal 5, level.maximum
      end

      def test_entity_exposure_false_only_enum_not_dropped
        schema = EntityIntrospector.new(RangeValuesEntity).build_schema
        flag = schema.properties["flag"]

        refute_nil flag
        assert_equal [false], flag.enum
      end

      # === Entity exposure values: Proc and hash-wrapped values ===

      class ProcValuesEntity < Grape::Entity
        expose :status, documentation: { type: String, values: proc { %w[active inactive] } }
        expose :priority, documentation: { type: String, values: { value: %w[low high], message: "pick one" } }
      end

      def test_entity_exposure_proc_values_evaluated_and_applied
        schema = EntityIntrospector.new(ProcValuesEntity).build_schema
        status = schema.properties["status"]

        refute_nil status
        assert_equal %w[active inactive], status.enum
      end

      def test_entity_exposure_hash_wrapped_values_unwrapped_and_applied
        schema = EntityIntrospector.new(ProcValuesEntity).build_schema
        priority = schema.properties["priority"]

        refute_nil priority
        assert_equal %w[low high], priority.enum
      end

      # === Entity exposure values: Range on nullable field ===

      class NullableRangeEntity < Grape::Entity
        expose :score, documentation: { type: Integer, nullable: true, values: 0..100 }
      end

      def test_entity_exposure_range_on_nullable_field_applies_min_max
        # nullable: true sets schema.nullable rather than producing a oneOf wrapper,
        # so min/max constraints are applied directly to the schema — valid OpenAPI.
        schema = EntityIntrospector.new(NullableRangeEntity).build_schema
        score = schema.properties["score"]

        refute_nil score
        assert score.nullable
        assert_equal 0, score.minimum
        assert_equal 100, score.maximum
      end
    end
  end
end
