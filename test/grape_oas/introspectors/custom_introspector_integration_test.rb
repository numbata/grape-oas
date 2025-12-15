# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    # Tests that custom introspectors are used for nested entities via the registry
    class CustomIntrospectorIntegrationTest < Minitest::Test
      # A custom introspector that wraps EntityIntrospector and adds custom behavior
      class CustomEntityIntrospector
        extend Base

        class << self
          attr_accessor :handled_entities, :build_count

          def reset_tracking
            @handled_entities = []
            @build_count = Hash.new(0)
          end

          def handles?(subject)
            return false unless EntityIntrospector.handles?(subject)

            entity_class = EntityIntrospector.resolve_entity_class(subject)
            entity_class&.name&.include?("CustomTracked")
          end

          def build_schema(subject, stack: [], registry: {})
            entity_class = EntityIntrospector.resolve_entity_class(subject)
            @handled_entities ||= []
            @handled_entities << entity_class.name
            @build_count ||= Hash.new(0)
            @build_count[entity_class.name] += 1

            schema = EntityIntrospector.build_schema(subject, stack: stack, registry: registry)
            # Add custom extension to mark it was processed by custom introspector
            schema.extensions ||= {}
            schema.extensions["x-custom-processed"] = true
            schema
          end
        end
      end

      # Test entities
      class CustomTrackedParentEntity < Grape::Entity
        expose :name, documentation: { type: String }
        expose :child, using: "GrapeOAS::Introspectors::CustomIntrospectorIntegrationTest::CustomTrackedChildEntity"
      end

      class CustomTrackedChildEntity < Grape::Entity
        expose :value, documentation: { type: Integer }
      end

      class RegularParentEntity < Grape::Entity
        expose :name, documentation: { type: String }
        expose :tracked_child, using: "GrapeOAS::Introspectors::CustomIntrospectorIntegrationTest::CustomTrackedChildEntity"
      end

      # Entity with multiple references to same child (tests caching)
      class ParentWithMultipleRefsEntity < Grape::Entity
        expose :name, documentation: { type: String }
        expose :first_child, using: "GrapeOAS::Introspectors::CustomIntrospectorIntegrationTest::CustomTrackedChildEntity"
        expose :second_child, using: "GrapeOAS::Introspectors::CustomIntrospectorIntegrationTest::CustomTrackedChildEntity"
      end

      def setup
        @original_introspectors = GrapeOAS.introspectors.to_a.dup
        CustomEntityIntrospector.reset_tracking
      end

      def teardown
        # Restore original introspectors
        GrapeOAS.introspectors.clear
        @original_introspectors.each { |i| GrapeOAS.introspectors.register(i) }
      end

      def test_custom_introspector_handles_nested_entity_via_registry
        # Register custom introspector before EntityIntrospector
        GrapeOAS.introspectors.register(
          CustomEntityIntrospector,
          before: EntityIntrospector,
        )

        # Build schema using the registry (simulating what ExposureProcessor does)
        schema = GrapeOAS.introspectors.build_schema(CustomTrackedParentEntity)

        # Custom introspector should have been called for both entities
        assert_includes CustomEntityIntrospector.handled_entities, CustomTrackedParentEntity.name
        assert_includes CustomEntityIntrospector.handled_entities, CustomTrackedChildEntity.name

        # Both schemas should have the custom extension
        assert schema.extensions["x-custom-processed"]
        assert schema.properties["child"].extensions["x-custom-processed"]
      end

      def test_custom_introspector_called_for_nested_entity_from_regular_parent
        # Register custom introspector before EntityIntrospector
        GrapeOAS.introspectors.register(
          CustomEntityIntrospector,
          before: EntityIntrospector,
        )

        # Build schema for a regular parent that has a tracked child
        schema = GrapeOAS.introspectors.build_schema(RegularParentEntity)

        # Parent should NOT be handled by custom introspector (doesn't match pattern)
        refute_includes CustomEntityIntrospector.handled_entities, RegularParentEntity.name

        # But child SHOULD be handled by custom introspector
        assert_includes CustomEntityIntrospector.handled_entities, CustomTrackedChildEntity.name

        # Parent should not have custom extension
        assert_nil schema.extensions&.dig("x-custom-processed")

        # Child should have custom extension
        assert schema.properties["tracked_child"].extensions["x-custom-processed"]
      end

      def test_registry_priority_order_respected
        # Create two introspectors that both handle the same entity
        first_called = []
        second_called = []

        first_introspector = Class.new do
          extend Base

          define_singleton_method(:handles?) do |subject|
            EntityIntrospector.handles?(subject)
          end

          define_singleton_method(:build_schema) do |subject, **_kwargs|
            first_called << subject
            # Return nil to let next introspector handle it
            nil
          end
        end

        second_introspector = Class.new do
          extend Base

          define_singleton_method(:handles?) do |subject|
            EntityIntrospector.handles?(subject)
          end

          define_singleton_method(:build_schema) do |subject, stack: [], registry: {}|
            second_called << subject
            EntityIntrospector.build_schema(subject, stack: stack, registry: registry)
          end
        end

        # Register first, then second
        GrapeOAS.introspectors.register(first_introspector, before: EntityIntrospector)
        GrapeOAS.introspectors.register(second_introspector, after: first_introspector)

        # Build schema
        GrapeOAS.introspectors.build_schema(CustomTrackedParentEntity)

        # First introspector should have been tried first
        assert_includes first_called, CustomTrackedParentEntity
      end

      def test_entity_introspector_caching_returns_same_schema_for_multiple_refs
        # This test verifies that EntityIntrospector's internal caching returns the same
        # schema object for multiple references to the same entity
        GrapeOAS.introspectors.register(
          CustomEntityIntrospector,
          before: EntityIntrospector,
        )

        schema = GrapeOAS.introspectors.build_schema(ParentWithMultipleRefsEntity)

        # Both child properties should reference the same schema object
        # (due to EntityIntrospector's registry caching)
        first_child = schema.properties["first_child"]
        second_child = schema.properties["second_child"]

        assert_same first_child, second_child,
                    "Multiple refs to same entity should return the same cached schema"
      end

      def test_dry_introspector_caching_returns_same_schema
        # Test that DryIntrospector properly caches schemas
        schema = Dry::Schema.JSON do
          required(:field).filled(:string)
        end
        schema.define_singleton_method(:schema_name) { "CachingTestSchema" }

        registry = {}
        result1 = DryIntrospector.build_schema(schema, registry: registry)
        result2 = DryIntrospector.build_schema(schema, registry: registry)

        assert_same result1, result2,
                    "DryIntrospector should return cached schema on second call"
      end

      def test_nested_schema_has_full_properties_not_just_canonical_name
        GrapeOAS.introspectors.register(
          CustomEntityIntrospector,
          before: EntityIntrospector,
        )

        schema = GrapeOAS.introspectors.build_schema(CustomTrackedParentEntity)

        # The nested child schema should have actual properties, not just a canonical_name
        child_schema = schema.properties["child"]

        assert child_schema.properties.key?("value"), "Nested schema should have properties"
        assert_equal "integer", child_schema.properties["value"].type
      end
    end

    # Tests for ExposureProcessor using registry for nested entities
    class ExposureProcessorRegistryUsageTest < Minitest::Test
      class NestedChildEntity < Grape::Entity
        expose :child_value, documentation: { type: String }
      end

      class ParentWithUsingEntity < Grape::Entity
        expose :name, documentation: { type: String }
        expose :nested, using: NestedChildEntity, documentation: { type: NestedChildEntity }
      end

      class ParentWithStringTypeEntity < Grape::Entity
        expose :name, documentation: { type: String }
        expose :nested, documentation: {
          type: "GrapeOAS::Introspectors::ExposureProcessorRegistryUsageTest::NestedChildEntity"
        }
      end

      def test_nested_entity_via_using_goes_through_registry
        # This test verifies the fix where ExposureProcessor now uses
        # GrapeOAS.introspectors.build_schema instead of EntityIntrospector.new directly

        schema = GrapeOAS.introspectors.build_schema(ParentWithUsingEntity)

        assert_equal "object", schema.type
        assert schema.properties.key?("nested")
        assert_equal "object", schema.properties["nested"].type
        assert schema.properties["nested"].properties.key?("child_value")
      end

      def test_nested_entity_via_string_type_goes_through_registry
        schema = GrapeOAS.introspectors.build_schema(ParentWithStringTypeEntity)

        assert_equal "object", schema.type
        assert schema.properties.key?("nested")
        assert_equal "object", schema.properties["nested"].type
        assert schema.properties["nested"].properties.key?("child_value")
      end
    end

    # Tests for Dry schema with schema_name support
    class DrySchemaNameIntegrationTest < Minitest::Test
      def test_dry_schema_with_schema_name_uses_name_as_canonical
        schema = Dry::Schema.JSON do
          required(:title).filled(:string)
          required(:count).filled(:integer)
        end
        schema.define_singleton_method(:schema_name) { "MyNamedSchema" }

        result = DryIntrospector.build_schema(schema)

        assert_equal "MyNamedSchema", result.canonical_name
        assert_equal "object", result.type
        assert result.properties.key?("title")
        assert result.properties.key?("count")
      end

      def test_dry_schema_cached_by_schema_name
        schema = Dry::Schema.JSON do
          required(:field).filled(:string)
        end
        schema.define_singleton_method(:schema_name) { "CachedByName" }

        registry = {}
        result1 = DryIntrospector.build_schema(schema, registry: registry)
        result2 = DryIntrospector.build_schema(schema, registry: registry)

        assert_same result1, result2, "Should return cached schema"
        assert registry.key?("CachedByName")
      end

      def test_multiple_dry_schemas_with_different_names_stored_separately
        schema1 = Dry::Schema.JSON do
          required(:field_a).filled(:string)
        end
        schema1.define_singleton_method(:schema_name) { "SchemaA" }

        schema2 = Dry::Schema.JSON do
          required(:field_b).filled(:integer)
        end
        schema2.define_singleton_method(:schema_name) { "SchemaB" }

        registry = {}
        result1 = DryIntrospector.build_schema(schema1, registry: registry)
        result2 = DryIntrospector.build_schema(schema2, registry: registry)

        refute_same result1, result2
        assert registry.key?("SchemaA")
        assert registry.key?("SchemaB")
        assert registry["SchemaA"].properties.key?("field_a")
        assert registry["SchemaB"].properties.key?("field_b")
      end

      def test_dry_contract_cached_by_class
        contract_class = Class.new(Dry::Validation::Contract) do
          params do
            required(:name).filled(:string)
          end
        end

        registry = {}
        result1 = DryIntrospector.build_schema(contract_class, registry: registry)
        result2 = DryIntrospector.build_schema(contract_class, registry: registry)

        assert_same result1, result2, "Should return cached schema for contract class"
        assert registry.key?(contract_class)
      end
    end

    # Tests for anyOf composition schemas with full properties in export
    class AnyOfExportIntegrationTest < Minitest::Test
      class TypeAEntity < Grape::Entity
        expose :type_a_field, documentation: { type: String }
      end

      class TypeBEntity < Grape::Entity
        expose :type_b_field, documentation: { type: Integer }
      end

      def test_anyof_composition_schemas_have_full_properties_for_export
        # Simulate what AnyOfIntrospector does - build full schemas for anyOf
        registry = {}
        schema_a = GrapeOAS.introspectors.build_schema(TypeAEntity, registry: registry)
        schema_b = GrapeOAS.introspectors.build_schema(TypeBEntity, registry: registry)

        # Create composition schema with full schemas (not placeholders)
        composition = ApiModel::Schema.new(
          type: "object",
          canonical_name: "CompositionSchema",
          any_of: [schema_a, schema_b],
        )

        # Verify the any_of schemas have actual properties
        assert composition.any_of[0].properties.key?("type_a_field")
        assert composition.any_of[1].properties.key?("type_b_field")

        # Verify they have canonical names for proper $ref generation
        assert_equal "GrapeOAS::Introspectors::AnyOfExportIntegrationTest::TypeAEntity",
                     composition.any_of[0].canonical_name
        assert_equal "GrapeOAS::Introspectors::AnyOfExportIntegrationTest::TypeBEntity",
                     composition.any_of[1].canonical_name
      end

      def test_anyof_with_dry_schemas_have_full_properties
        # Create Dry schemas with schema_name (simulating user's setup)
        dry_schema1 = Dry::Schema.JSON do
          required(:dry_field_1).filled(:string)
        end
        dry_schema1.define_singleton_method(:schema_name) { "DrySchema1" }

        dry_schema2 = Dry::Schema.JSON do
          required(:dry_field_2).filled(:integer)
        end
        dry_schema2.define_singleton_method(:schema_name) { "DrySchema2" }

        registry = {}
        built1 = GrapeOAS.introspectors.build_schema(dry_schema1, registry: registry)
        built2 = GrapeOAS.introspectors.build_schema(dry_schema2, registry: registry)

        # Create composition with full built schemas
        composition = ApiModel::Schema.new(
          type: "object",
          canonical_name: "DryComposition",
          any_of: [built1, built2],
        )

        # Verify both schemas in any_of have their properties
        assert composition.any_of[0].properties.key?("dry_field_1"),
               "First Dry schema should have its properties"
        assert composition.any_of[1].properties.key?("dry_field_2"),
               "Second Dry schema should have its properties"

        # Verify canonical names
        assert_equal "DrySchema1", composition.any_of[0].canonical_name
        assert_equal "DrySchema2", composition.any_of[1].canonical_name
      end

      def test_schema_indexer_collects_anyof_schemas_with_properties
        # This tests that the exporter's collect_refs properly finds schemas in any_of
        dry_schema = Dry::Schema.JSON do
          required(:indexed_field).filled(:string)
        end
        dry_schema.define_singleton_method(:schema_name) { "IndexedSchema" }

        registry = {}
        built_schema = GrapeOAS.introspectors.build_schema(dry_schema, registry: registry)

        composition = ApiModel::Schema.new(
          type: "object",
          canonical_name: "ParentComposition",
          any_of: [built_schema],
        )

        # Simulate what SchemaIndexer.collect_refs does
        ref_schemas = {}
        pending = []

        composition.any_of.each do |sub_schema|
          if sub_schema.canonical_name
            pending << sub_schema.canonical_name
            ref_schemas[sub_schema.canonical_name] = sub_schema
          end
        end

        # The collected schema should have full properties
        assert ref_schemas.key?("IndexedSchema")
        assert ref_schemas["IndexedSchema"].properties.key?("indexed_field"),
               "Collected schema should have properties, not be an empty placeholder"
      end
    end

    # Tests that Response builder uses introspector registry instead of EntityIntrospector directly
    class ResponseBuilderRegistryUsageTest < Minitest::Test
      # A tracking introspector that records when it's called
      class TrackingIntrospector
        extend Base

        class << self
          attr_accessor :handled_entities

          def reset_tracking
            @handled_entities = []
          end

          def handles?(subject)
            return false unless EntityIntrospector.handles?(subject)

            entity_class = EntityIntrospector.resolve_entity_class(subject)
            entity_class&.name&.include?("TrackedResponse")
          end

          def build_schema(subject, stack: [], registry: {})
            entity_class = EntityIntrospector.resolve_entity_class(subject)
            @handled_entities ||= []
            @handled_entities << entity_class.name

            schema = EntityIntrospector.build_schema(subject, stack: stack, registry: registry)
            schema.extensions ||= {}
            schema.extensions["x-tracked-by-registry"] = true
            schema
          end
        end
      end

      class TrackedResponseEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :name, documentation: { type: String }
      end

      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
        @original_introspectors = GrapeOAS.introspectors.to_a.dup
        TrackingIntrospector.reset_tracking
      end

      def teardown
        GrapeOAS.introspectors.clear
        @original_introspectors.each { |i| GrapeOAS.introspectors.register(i) }
      end

      def test_response_builder_uses_introspector_registry
        # Register tracking introspector before EntityIntrospector
        GrapeOAS.introspectors.register(
          TrackingIntrospector,
          before: EntityIntrospector,
        )

        api_class = Class.new(Grape::API) do
          format :json
          get "items", entity: TrackedResponseEntity do
            {}
          end
        end

        route = api_class.routes.first
        builder = ApiModelBuilders::Response.new(api: @api, route: route)
        responses = builder.build
        response = responses.first

        # Verify the tracking introspector was called
        assert_includes TrackingIntrospector.handled_entities, TrackedResponseEntity.name,
                        "Response builder should use introspector registry"

        # Verify the schema has our custom extension
        schema = response.media_types.first.schema

        assert schema.extensions&.dig("x-tracked-by-registry"),
               "Schema should have been processed by our tracking introspector"
      end
    end

    # Tests that ParamSchemaBuilder uses introspector registry instead of EntityIntrospector directly
    class ParamSchemaBuilderRegistryUsageTest < Minitest::Test
      # A tracking introspector for param schema tests
      class ParamTrackingIntrospector
        extend Base

        class << self
          attr_accessor :handled_entities

          def reset_tracking
            @handled_entities = []
          end

          def handles?(subject)
            return false unless EntityIntrospector.handles?(subject)

            entity_class = EntityIntrospector.resolve_entity_class(subject)
            entity_class&.name&.include?("TrackedParam")
          end

          def build_schema(subject, stack: [], registry: {})
            entity_class = EntityIntrospector.resolve_entity_class(subject)
            @handled_entities ||= []
            @handled_entities << entity_class.name

            schema = EntityIntrospector.build_schema(subject, stack: stack, registry: registry)
            schema.extensions ||= {}
            schema.extensions["x-param-tracked"] = true
            schema
          end
        end
      end

      class TrackedParamEntity < Grape::Entity
        expose :field, documentation: { type: String }
      end

      def setup
        @original_introspectors = GrapeOAS.introspectors.to_a.dup
        ParamTrackingIntrospector.reset_tracking
      end

      def teardown
        GrapeOAS.introspectors.clear
        @original_introspectors.each { |i| GrapeOAS.introspectors.register(i) }
      end

      def test_param_schema_builder_uses_registry_for_entity_type
        GrapeOAS.introspectors.register(
          ParamTrackingIntrospector,
          before: EntityIntrospector,
        )

        spec = { type: TrackedParamEntity, documentation: {} }
        schema = ApiModelBuilders::RequestParamsSupport::ParamSchemaBuilder.build(spec)

        assert_includes ParamTrackingIntrospector.handled_entities, TrackedParamEntity.name,
                        "ParamSchemaBuilder should use introspector registry for entity types"
        assert schema.extensions&.dig("x-param-tracked"),
               "Schema should have been processed by our tracking introspector"
      end

      def test_param_schema_builder_uses_registry_for_array_of_entities
        GrapeOAS.introspectors.register(
          ParamTrackingIntrospector,
          before: EntityIntrospector,
        )

        spec = { type: Array, documentation: { type: TrackedParamEntity } }
        schema = ApiModelBuilders::RequestParamsSupport::ParamSchemaBuilder.build(spec)

        assert_includes ParamTrackingIntrospector.handled_entities, TrackedParamEntity.name,
                        "ParamSchemaBuilder should use registry for array element entity types"
        assert_equal "array", schema.type
        assert schema.items.extensions&.dig("x-param-tracked"),
               "Array items schema should have been processed by our tracking introspector"
      end

      def test_param_schema_builder_uses_registry_for_elements_option
        GrapeOAS.introspectors.register(
          ParamTrackingIntrospector,
          before: EntityIntrospector,
        )

        spec = { type: Array, elements: TrackedParamEntity, documentation: {} }
        schema = ApiModelBuilders::RequestParamsSupport::ParamSchemaBuilder.build(spec)

        assert_includes ParamTrackingIntrospector.handled_entities, TrackedParamEntity.name,
                        "ParamSchemaBuilder should use registry for elements option"
        assert_equal "array", schema.type
        assert schema.items.extensions&.dig("x-param-tracked"),
               "Array items schema should have been processed by our tracking introspector"
      end

      def test_param_schema_builder_uses_registry_for_doc_type_array
        GrapeOAS.introspectors.register(
          ParamTrackingIntrospector,
          before: EntityIntrospector,
        )

        spec = { type: String, documentation: { type: TrackedParamEntity, is_array: true } }
        schema = ApiModelBuilders::RequestParamsSupport::ParamSchemaBuilder.build(spec)

        assert_includes ParamTrackingIntrospector.handled_entities, TrackedParamEntity.name,
                        "ParamSchemaBuilder should use registry for doc type array"
        assert_equal "array", schema.type
        assert schema.items.extensions&.dig("x-param-tracked"),
               "Array items schema should have been processed by our tracking introspector"
      end
    end
  end
end
