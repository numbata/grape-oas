# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class BaseTest < Minitest::Test
      class IncompleteResolver
        extend Base
      end

      def test_handles_raises_not_implemented_error
        error = assert_raises(NotImplementedError) { IncompleteResolver.handles?("String") }

        assert_match(/must implement/, error.message)
      end

      def test_build_schema_raises_not_implemented_error
        error = assert_raises(NotImplementedError) { IncompleteResolver.build_schema("String") }

        assert_match(/must implement/, error.message)
      end
    end
  end
end
