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

      def test_register_rejects_default_resolver
        error = assert_raises(ArgumentError) { @registry.register(DefaultResolver) }
        assert_match(/must not be registered/, error.message)
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

      # === Resolver lookup tests ===

      def test_registered_resolver_for_returns_true_for_matching_resolver
        @registry.register(MockResolver)

        assert @registry.registered_resolver_for?(:mock)
      end

      def test_registered_resolver_for_returns_false_for_no_match
        @registry.register(MockResolver)

        refute @registry.registered_resolver_for?(:unknown)
      end

      def test_handles_emits_deprecation_warning
        @registry.register(MockResolver)

        assert_output(nil, /deprecated.*registered_resolver_for\?/) do
          @registry.handles?(:mock)
        end
      end

      # === build_schema tests ===

      def test_build_schema_uses_correct_resolver
        @registry.register(MockResolver)

        schema = @registry.build_schema(:mock)

        assert_equal "string", schema.type
        assert_equal "mock", schema.description
      end

      def test_build_schema_skips_resolver_that_handles_but_returns_nil
        # Resolver claims to handle :flaky but returns nil from build_schema
        flaky = Class.new do
          extend Base

          def self.handles?(type)
            type == :flaky
          end

          def self.build_schema(_type)
            nil
          end
        end

        @registry.register(flaky)
        @registry.register(MockResolver)

        schema = @registry.build_schema(:flaky)

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end

      def test_build_schema_falls_back_to_default_resolver_for_no_match
        schema = @registry.build_schema(:unknown)

        assert_equal Constants::SchemaTypes::STRING, schema.type
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
