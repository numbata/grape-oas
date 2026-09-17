# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class ApiModelBuilderTest < Minitest::Test
    class BrokenIntrospector
      def self.handles?(subject)
        subject == :broken
      end

      def self.build_schema(_subject, stack:, registry:)
        _ = [stack, registry]
        raise "introspector bug"
      end
    end

    def test_raises_for_missing_model_name
      assert_raises(NameError) do
        ApiModelBuilder.new(models: ["MissingExplicitModel"])
      end
    end

    def test_raises_for_unsupported_model
      error = assert_raises(ArgumentError) do
        ApiModelBuilder.new(models: [:unsupported])
      end

      assert_equal "No introspector can build a schema for :unsupported", error.message
    end

    def test_propagates_introspector_error
      GrapeOAS.introspectors.register(BrokenIntrospector)

      error = assert_raises(RuntimeError) do
        ApiModelBuilder.new(models: [:broken])
      end

      assert_equal "introspector bug", error.message
    ensure
      GrapeOAS.introspectors.unregister(BrokenIntrospector)
    end
  end
end
