# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class RegistryTest < Minitest::Test
      # Mock resolver for testing
      class MockResolver
        extend Base

        def self.handles?(type)
          type == :mock
        end

        def self.build_schema(_type)
          ApiModel::Schema.new(type: "string", description: "mock")
        end
      end

      # Another mock for ordering tests
      class AnotherMockResolver
        extend Base

        def self.handles?(type)
          type == :another
        end

        def self.build_schema(_type)
          ApiModel::Schema.new(type: "integer")
        end
      end

      def setup
        @registry = Registry.new
      end

      # === Registration tests ===

      def test_register_adds_resolver
        @registry.register(MockResolver)

        assert_equal 1, @registry.size
        assert_includes @registry.to_a, MockResolver
      end

      def test_register_prevents_duplicates
        @registry.register(MockResolver)
        @registry.register(MockResolver)

        assert_equal 1, @registry.size
      end

      def test_register_returns_self_for_chaining
        result = @registry.register(MockResolver)

        assert_same @registry, result
      end

      def test_register_validates_resolver_interface
        invalid = Object.new

        error = assert_raises(ArgumentError) { @registry.register(invalid) }
        assert_match(/must respond to/, error.message)
      end

      def test_register_before_inserts_at_correct_position
        @registry.register(MockResolver)
        @registry.register(AnotherMockResolver, before: MockResolver)

        assert_equal [AnotherMockResolver, MockResolver], @registry.to_a
      end

      def test_register_after_inserts_at_correct_position
        @registry.register(MockResolver)
        @registry.register(AnotherMockResolver, after: MockResolver)

        assert_equal [MockResolver, AnotherMockResolver], @registry.to_a
      end

      # === Unregister tests ===

      def test_unregister_removes_resolver
        @registry.register(MockResolver)
        @registry.unregister(MockResolver)

        assert_equal 0, @registry.size
      end

      # === Finding tests ===

      def test_find_returns_matching_resolver
        @registry.register(MockResolver)

        result = @registry.find(:mock)

        assert_equal MockResolver, result
      end

      def test_find_returns_nil_for_no_match
        @registry.register(MockResolver)

        result = @registry.find(:unknown)

        assert_nil result
      end

      # === build_schema tests ===

      def test_build_schema_uses_correct_resolver
        @registry.register(MockResolver)

        schema = @registry.build_schema(:mock)

        assert_equal "string", schema.type
        assert_equal "mock", schema.description
      end

      def test_build_schema_returns_nil_for_no_match
        result = @registry.build_schema(:unknown)

        assert_nil result
      end

      # === handles? tests ===

      def test_handles_returns_true_when_resolver_found
        @registry.register(MockResolver)

        assert @registry.handles?(:mock)
      end

      def test_handles_returns_false_when_no_resolver
        refute @registry.handles?(:unknown)
      end

      # === Enumerable tests ===

      def test_size_returns_count
        assert_equal 0, @registry.size

        @registry.register(MockResolver)
        assert_equal 1, @registry.size
      end

      def test_clear_removes_all
        @registry.register(MockResolver)
        @registry.register(AnotherMockResolver)

        @registry.clear

        assert_equal 0, @registry.size
      end
    end
  end
end
