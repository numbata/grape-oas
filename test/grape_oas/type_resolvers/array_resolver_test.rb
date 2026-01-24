# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class ArrayResolverTest < Minitest::Test
      # === handles? tests ===

      def test_handles_string_array_notation
        assert ArrayResolver.handles?("[String]")
      end

      def test_handles_integer_array_notation
        assert ArrayResolver.handles?("[Integer]")
      end

      def test_handles_namespaced_type_array
        assert ArrayResolver.handles?("[MyModule::MyType]")
      end

      def test_does_not_handle_non_array_string
        refute ArrayResolver.handles?("String")
      end

      def test_does_not_handle_non_string
        refute ArrayResolver.handles?(Integer)
      end

      def test_does_not_handle_empty_brackets
        refute ArrayResolver.handles?("[]")
      end

      # === build_schema tests for basic types ===

      def test_builds_array_of_strings
        schema = ArrayResolver.build_schema("[String]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::STRING, schema.items.type
      end

      def test_builds_array_of_integers
        schema = ArrayResolver.build_schema("[Integer]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::INTEGER, schema.items.type
      end

      def test_builds_array_of_floats
        schema = ArrayResolver.build_schema("[Float]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::NUMBER, schema.items.type
      end

      def test_builds_array_of_booleans_true_class
        schema = ArrayResolver.build_schema("[TrueClass]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::BOOLEAN, schema.items.type
      end

      def test_builds_array_of_grape_api_boolean
        schema = ArrayResolver.build_schema("[Grape::API::Boolean]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::BOOLEAN, schema.items.type
      end

      def test_builds_array_of_files
        schema = ArrayResolver.build_schema("[File]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::FILE, schema.items.type
      end

      # === build_schema tests for namespaced types ===

      def test_builds_array_with_unknown_namespaced_type_as_string
        # If we can't resolve the class, it falls back to string parsing
        schema = ArrayResolver.build_schema("[Unknown::Module::Type]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::STRING, schema.items.type
      end

      # === build_schema tests for format inference ===

      def test_infers_uuid_format_from_type_name
        schema = ArrayResolver.build_schema("[SomeModule::UUID]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal "uuid", schema.items.format
      end

      def test_infers_datetime_format_from_type_name
        schema = ArrayResolver.build_schema("[SomeModule::DateTime]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal "date-time", schema.items.format
      end

      def test_infers_date_format_from_type_name
        schema = ArrayResolver.build_schema("[SomeModule::Date]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal "date", schema.items.format
      end

      def test_infers_email_format_from_type_name
        schema = ArrayResolver.build_schema("[SomeModule::Email]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal "email", schema.items.format
      end

      def test_infers_uri_format_from_type_name
        schema = ArrayResolver.build_schema("[SomeModule::URI]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal "uri", schema.items.format
      end

      def test_build_schema_does_not_raise_when_bigdecimal_constant_is_missing
        original_bigdecimal = Object.const_get(:BigDecimal) if Object.const_defined?(:BigDecimal)

        Object.send(:remove_const, :BigDecimal) if Object.const_defined?(:BigDecimal)

        schema = ArrayResolver.build_schema("[Float]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::NUMBER, schema.items.type
      ensure
        Object.const_set(:BigDecimal, original_bigdecimal) if original_bigdecimal && !Object.const_defined?(:BigDecimal)
      end
    end
  end
end
