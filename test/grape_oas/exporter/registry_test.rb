# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class RegistryTest < Minitest::Test
      # Mock exporter for testing
      class MockExporter
        def initialize(api_model:)
          @api = api_model
        end

        def generate
          { "mock" => true }
        end
      end

      def setup
        @registry = Registry.new
      end

      # === Registration tests ===

      def test_register_with_single_alias
        @registry.register(MockExporter, as: :mock)

        assert_equal 1, @registry.size
        assert @registry.registered?(:mock)
      end

      def test_register_with_multiple_aliases
        @registry.register(MockExporter, as: %i[mock mock2])

        assert_equal 2, @registry.size
        assert @registry.registered?(:mock)
        assert @registry.registered?(:mock2)
        assert_equal MockExporter, @registry.for(:mock)
        assert_equal MockExporter, @registry.for(:mock2)
      end

      def test_register_overwrites_existing
        @registry.register(MockExporter, as: :mock)
        @registry.register(OAS2Schema, as: :mock)

        assert_equal 1, @registry.size
        assert_equal OAS2Schema, @registry.for(:mock)
      end

      def test_register_returns_self_for_chaining
        result = @registry.register(MockExporter, as: :mock)

        assert_same @registry, result
      end

      # === Unregister tests ===

      def test_unregister_single_type
        @registry.register(MockExporter, as: :mock)
        @registry.unregister(:mock)

        assert_equal 0, @registry.size
        refute @registry.registered?(:mock)
      end

      def test_unregister_multiple_types
        @registry.register(MockExporter, as: %i[mock mock2])
        @registry.unregister(:mock, :mock2)

        assert_equal 0, @registry.size
      end

      def test_unregister_returns_self
        result = @registry.unregister(:mock)

        assert_same @registry, result
      end

      # === Finding tests ===

      def test_for_returns_exporter_class
        @registry.register(MockExporter, as: :mock)

        result = @registry.for(:mock)

        assert_equal MockExporter, result
      end

      def test_for_raises_for_unknown_type
        error = assert_raises(ArgumentError) { @registry.for(:unknown) }

        assert_match(/Unsupported schema type/, error.message)
      end

      # === registered? tests ===

      def test_registered_returns_true_when_registered
        @registry.register(MockExporter, as: :mock)

        assert @registry.registered?(:mock)
      end

      def test_registered_returns_false_when_not_registered
        refute @registry.registered?(:mock)
      end

      # === schema_types tests ===

      def test_schema_types_returns_registered_types
        @registry.register(OAS2Schema, as: :oas2)
        @registry.register(OAS30Schema, as: :oas3)

        types = @registry.schema_types

        assert_includes types, :oas2
        assert_includes types, :oas3
      end

      # === Utility tests ===

      def test_size_returns_count
        assert_equal 0, @registry.size
        @registry.register(MockExporter, as: :mock)

        assert_equal 1, @registry.size
      end

      def test_clear_removes_all
        @registry.register(OAS2Schema, as: :oas2)
        @registry.register(OAS30Schema, as: :oas3)
        @registry.clear

        assert_equal 0, @registry.size
      end

      # === Global registry tests ===

      def test_global_registry_exists
        registry = GrapeOAS.exporters

        assert_instance_of Registry, registry
      end

      def test_global_registry_includes_oas2
        assert GrapeOAS.exporters.registered?(:oas2)
        assert_equal OAS2Schema, GrapeOAS.exporters.for(:oas2)
      end

      def test_global_registry_includes_oas3
        assert GrapeOAS.exporters.registered?(:oas3)
        assert_equal OAS30Schema, GrapeOAS.exporters.for(:oas3)
      end

      def test_global_registry_includes_oas30
        assert GrapeOAS.exporters.registered?(:oas30)
        assert_equal OAS30Schema, GrapeOAS.exporters.for(:oas30)
      end

      def test_global_registry_includes_oas31
        assert GrapeOAS.exporters.registered?(:oas31)
        assert_equal OAS31Schema, GrapeOAS.exporters.for(:oas31)
      end

      def test_exporter_for_delegates_to_registry
        exporter = GrapeOAS::Exporter.for(:oas3)

        assert_equal OAS30Schema, exporter
      end
    end
  end
end
