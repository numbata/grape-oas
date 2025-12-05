# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class RegistryTest < Minitest::Test
      # Mock introspector for testing
      class MockIntrospector
        extend Base

        def self.handles?(subject)
          subject.is_a?(Hash) && subject[:type] == :mock
        end

        def self.build_schema(subject, stack: [], registry: {}) # rubocop:disable Lint/UnusedMethodArgument
          ApiModel::Schema.new(type: "object", description: subject[:desc])
        end
      end

      # Another mock for ordering tests
      class AnotherMockIntrospector
        extend Base

        def self.handles?(subject)
          subject.is_a?(Hash) && subject[:type] == :another
        end

        def self.build_schema(_subject, stack: [], registry: {}) # rubocop:disable Lint/UnusedMethodArgument
          ApiModel::Schema.new(type: "string")
        end
      end

      def setup
        @registry = Registry.new
      end

      # === Registration tests ===

      def test_register_adds_introspector
        @registry.register(MockIntrospector)

        assert_equal 1, @registry.size
        assert_includes @registry.to_a, MockIntrospector
      end

      def test_register_prevents_duplicates
        @registry.register(MockIntrospector)
        @registry.register(MockIntrospector)

        assert_equal 1, @registry.size
      end

      def test_register_returns_self_for_chaining
        result = @registry.register(MockIntrospector)

        assert_same @registry, result
      end

      def test_register_validates_introspector_interface
        invalid = Object.new

        error = assert_raises(ArgumentError) { @registry.register(invalid) }
        assert_match(/must respond to/, error.message)
      end

      def test_register_before_inserts_at_correct_position
        @registry.register(MockIntrospector)
        @registry.register(AnotherMockIntrospector, before: MockIntrospector)

        assert_equal [AnotherMockIntrospector, MockIntrospector], @registry.to_a
      end

      def test_register_after_inserts_at_correct_position
        @registry.register(MockIntrospector)
        @registry.register(AnotherMockIntrospector, after: MockIntrospector)

        assert_equal [MockIntrospector, AnotherMockIntrospector], @registry.to_a
      end

      def test_register_before_nonexistent_appends
        @registry.register(MockIntrospector)
        @registry.register(AnotherMockIntrospector, before: Object)

        assert_equal [MockIntrospector, AnotherMockIntrospector], @registry.to_a
      end

      # === Unregister tests ===

      def test_unregister_removes_introspector
        @registry.register(MockIntrospector)
        @registry.unregister(MockIntrospector)

        assert_equal 0, @registry.size
      end

      def test_unregister_returns_self
        result = @registry.unregister(MockIntrospector)

        assert_same @registry, result
      end

      # === Finding tests ===

      def test_find_returns_matching_introspector
        @registry.register(MockIntrospector)

        result = @registry.find({ type: :mock })

        assert_equal MockIntrospector, result
      end

      def test_find_returns_nil_for_no_match
        @registry.register(MockIntrospector)

        result = @registry.find({ type: :unknown })

        assert_nil result
      end

      def test_find_returns_first_match
        # Register AnotherMock first, then Mock
        @registry.register(AnotherMockIntrospector)
        @registry.register(MockIntrospector)

        # AnotherMock handles :another, Mock handles :mock
        assert_equal AnotherMockIntrospector, @registry.find({ type: :another })
        assert_equal MockIntrospector, @registry.find({ type: :mock })
      end

      # === handles? tests ===

      def test_handles_returns_true_when_introspector_found
        @registry.register(MockIntrospector)

        assert @registry.handles?({ type: :mock })
      end

      def test_handles_returns_false_when_no_introspector
        refute @registry.handles?({ type: :mock })
      end

      # === build_schema tests ===

      def test_build_schema_uses_correct_introspector
        @registry.register(MockIntrospector)

        schema = @registry.build_schema({ type: :mock, desc: "test" })

        assert_equal "object", schema.type
        assert_equal "test", schema.description
      end

      def test_build_schema_returns_nil_for_no_match
        result = @registry.build_schema({ type: :unknown })

        assert_nil result
      end

      def test_build_schema_passes_stack_and_registry
        tracker = Class.new do
          extend Base

          class << self
            attr_accessor :received_stack, :received_registry
          end

          def self.handles?(subject)
            subject == :tracked
          end

          def self.build_schema(_subject, stack: [], registry: {})
            self.received_stack = stack
            self.received_registry = registry
            nil
          end
        end

        @registry.register(tracker)
        @registry.build_schema(:tracked, stack: [:a], registry: { b: 1 })

        assert_equal [:a], tracker.received_stack
        assert_equal({ b: 1 }, tracker.received_registry)
      end

      # === Enumerable tests ===

      def test_each_iterates_over_introspectors
        @registry.register(MockIntrospector)
        @registry.register(AnotherMockIntrospector)

        collected = @registry.map { |i| i }

        assert_equal [MockIntrospector, AnotherMockIntrospector], collected
      end

      def test_size_returns_count
        assert_equal 0, @registry.size
        @registry.register(MockIntrospector)

        assert_equal 1, @registry.size
      end

      def test_clear_removes_all
        @registry.register(MockIntrospector)
        @registry.register(AnotherMockIntrospector)

        @registry.clear

        assert_equal 0, @registry.size
      end

      # === to_a returns copy ===

      def test_to_a_returns_copy
        @registry.register(MockIntrospector)

        array = @registry.to_a
        array.clear

        assert_equal 1, @registry.size
      end
    end
  end
end
