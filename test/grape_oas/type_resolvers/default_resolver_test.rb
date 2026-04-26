# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class DefaultResolverTest < Minitest::Test
      def test_handles_any_type
        assert DefaultResolver.handles?("anything")
        assert DefaultResolver.handles?(String)
        assert DefaultResolver.handles?(nil)
        assert DefaultResolver.handles?(42)
      end

      def test_builds_string_schema
        schema = DefaultResolver.build_schema("UnknownType")

        assert_equal Constants::SchemaTypes::STRING, schema.type
        assert_nil schema.format
      end

      def test_builds_string_schema_for_class
        unknown = Class.new
        schema = DefaultResolver.build_schema(unknown)

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end

      def test_builds_string_schema_for_nil
        schema = DefaultResolver.build_schema(nil)

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end
    end
  end
end
