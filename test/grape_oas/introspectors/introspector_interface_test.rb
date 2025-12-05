# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class IntrospectorInterfaceTest < Minitest::Test
      # Test entity for EntityIntrospector tests
      class TestEntity < Grape::Entity
        expose :name, documentation: { type: String }
      end

      # Test contract for DryIntrospector tests
      class TestContract < Dry::Validation::Contract
        params do
          required(:email).filled(:string)
        end
      end

      # === EntityIntrospector.handles? tests ===

      def test_entity_introspector_handles_entity_class
        assert EntityIntrospector.handles?(TestEntity)
      end

      def test_entity_introspector_handles_grape_entity_base
        assert EntityIntrospector.handles?(Grape::Entity)
      end

      def test_entity_introspector_does_not_handle_non_entity
        refute EntityIntrospector.handles?(String)
        refute EntityIntrospector.handles?(Object)
        refute EntityIntrospector.handles?(nil)
        refute EntityIntrospector.handles?(123)
      end

      def test_entity_introspector_handles_entity_string_constant
        # Only works if constant is defined
        Object.const_set(:IntrospectorTestEntity, TestEntity) unless defined?(::IntrospectorTestEntity)

        assert EntityIntrospector.handles?("IntrospectorTestEntity")
      ensure
        Object.send(:remove_const, :IntrospectorTestEntity) if defined?(::IntrospectorTestEntity)
      end

      def test_entity_introspector_does_not_handle_unknown_string
        refute EntityIntrospector.handles?("NonExistentClass")
      end

      def test_entity_introspector_does_not_handle_lowercase_string
        refute EntityIntrospector.handles?("lowercase_name")
      end

      # === EntityIntrospector.build_schema tests ===

      def test_entity_introspector_class_method_builds_schema
        schema = EntityIntrospector.build_schema(TestEntity)

        assert_equal "object", schema.type
        assert schema.properties.key?("name")
      end

      def test_entity_introspector_class_method_returns_nil_for_non_entity
        result = EntityIntrospector.build_schema(String)

        assert_nil result
      end

      def test_entity_introspector_class_method_passes_options
        registry = {}
        EntityIntrospector.build_schema(TestEntity, stack: [], registry: registry)

        # Registry should be populated
        assert registry.key?(TestEntity)
      end

      # === DryIntrospector.handles? tests ===

      def test_dry_introspector_handles_contract_class
        assert DryIntrospector.handles?(TestContract)
      end

      def test_dry_introspector_handles_contract_schema
        schema = TestContract.schema

        assert DryIntrospector.handles?(schema)
      end

      def test_dry_introspector_does_not_handle_non_contract
        refute DryIntrospector.handles?(String)
        refute DryIntrospector.handles?(Object)
        refute DryIntrospector.handles?(nil)
      end

      # === DryIntrospector.build_schema tests ===

      def test_dry_introspector_class_method_builds_schema
        schema = DryIntrospector.build_schema(TestContract)

        assert_equal "object", schema.type
        assert schema.properties.key?("email")
      end

      def test_dry_introspector_legacy_build_method_works
        schema = DryIntrospector.build(TestContract)

        assert_equal "object", schema.type
      end

      # === Global registry tests ===

      def test_global_registry_exists
        registry = GrapeOAS.introspectors

        assert_instance_of Registry, registry
      end

      def test_global_registry_includes_entity_introspector
        registry = GrapeOAS.introspectors

        assert_includes registry.to_a, EntityIntrospector
      end

      def test_global_registry_includes_dry_introspector
        registry = GrapeOAS.introspectors

        assert_includes registry.to_a, DryIntrospector
      end

      def test_global_registry_finds_entity_introspector
        introspector = GrapeOAS.introspectors.find(TestEntity)

        assert_equal EntityIntrospector, introspector
      end

      def test_global_registry_finds_dry_introspector
        introspector = GrapeOAS.introspectors.find(TestContract)

        assert_equal DryIntrospector, introspector
      end

      def test_global_registry_builds_entity_schema
        schema = GrapeOAS.introspectors.build_schema(TestEntity)

        assert_equal "object", schema.type
        assert schema.properties.key?("name")
      end

      def test_global_registry_builds_contract_schema
        schema = GrapeOAS.introspectors.build_schema(TestContract)

        assert_equal "object", schema.type
        assert schema.properties.key?("email")
      end
    end
  end
end
