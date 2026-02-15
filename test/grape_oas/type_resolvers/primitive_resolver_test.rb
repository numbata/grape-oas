# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class PrimitiveResolverTest < Minitest::Test
      # === handles? tests ===

      def test_handles_string
        assert PrimitiveResolver.handles?("String")
      end

      def test_handles_integer
        assert PrimitiveResolver.handles?("Integer")
      end

      def test_handles_float
        assert PrimitiveResolver.handles?("Float")
      end

      def test_handles_boolean
        assert PrimitiveResolver.handles?("Boolean")
      end

      def test_handles_date
        assert PrimitiveResolver.handles?("Date")
      end

      def test_handles_datetime
        assert PrimitiveResolver.handles?("DateTime")
      end

      def test_handles_time
        assert PrimitiveResolver.handles?("Time")
      end

      def test_handles_hash
        assert PrimitiveResolver.handles?("Hash")
      end

      def test_handles_array
        assert PrimitiveResolver.handles?("Array")
      end

      def test_handles_file
        assert PrimitiveResolver.handles?("File")
      end

      def test_handles_grape_boolean
        assert PrimitiveResolver.handles?("Grape::API::Boolean")
      end

      def test_handles_ruby_class_directly
        assert PrimitiveResolver.handles?(Integer)
      end

      # === build_schema tests ===

      def test_builds_string_schema
        schema = PrimitiveResolver.build_schema("String")

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end

      def test_builds_integer_schema
        schema = PrimitiveResolver.build_schema("Integer")

        assert_equal Constants::SchemaTypes::INTEGER, schema.type
        assert_equal "int32", schema.format
      end

      def test_builds_float_schema
        schema = PrimitiveResolver.build_schema("Float")

        assert_equal Constants::SchemaTypes::NUMBER, schema.type
        assert_equal "float", schema.format
      end

      def test_builds_bigdecimal_schema
        schema = PrimitiveResolver.build_schema("BigDecimal")

        assert_equal Constants::SchemaTypes::NUMBER, schema.type
        assert_equal "double", schema.format
      end

      def test_builds_boolean_schema
        schema = PrimitiveResolver.build_schema("Boolean")

        assert_equal Constants::SchemaTypes::BOOLEAN, schema.type
      end

      def test_builds_date_schema
        schema = PrimitiveResolver.build_schema("Date")

        assert_equal Constants::SchemaTypes::STRING, schema.type
        assert_equal "date", schema.format
      end

      def test_builds_datetime_schema
        schema = PrimitiveResolver.build_schema("DateTime")

        assert_equal Constants::SchemaTypes::STRING, schema.type
        assert_equal "date-time", schema.format
      end

      def test_builds_time_schema
        schema = PrimitiveResolver.build_schema("Time")

        assert_equal Constants::SchemaTypes::STRING, schema.type
        assert_equal "date-time", schema.format
      end

      def test_builds_hash_schema
        schema = PrimitiveResolver.build_schema("Hash")

        assert_equal Constants::SchemaTypes::OBJECT, schema.type
      end

      def test_builds_array_schema
        schema = PrimitiveResolver.build_schema("Array")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
      end

      def test_builds_file_schema
        schema = PrimitiveResolver.build_schema("File")

        assert_equal Constants::SchemaTypes::FILE, schema.type
      end

      def test_builds_schema_from_ruby_class
        schema = PrimitiveResolver.build_schema(Integer)

        assert_equal Constants::SchemaTypes::INTEGER, schema.type
      end

      def test_unknown_type_defaults_to_string
        schema = PrimitiveResolver.build_schema("UnknownType")

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end

      def test_handles_does_not_raise_when_date_constants_are_missing
        original_date = Object.const_get(:Date) if Object.const_defined?(:Date)
        original_datetime = Object.const_get(:DateTime) if Object.const_defined?(:DateTime)
        original_namespace = Object.const_get(:PrimitiveResolverTestNamespace) if Object.const_defined?(:PrimitiveResolverTestNamespace)

        Object.send(:remove_const, :Date) if Object.const_defined?(:Date)
        Object.send(:remove_const, :DateTime) if Object.const_defined?(:DateTime)

        Object.send(:remove_const, :PrimitiveResolverTestNamespace) if Object.const_defined?(:PrimitiveResolverTestNamespace)
        Object.const_set(:PrimitiveResolverTestNamespace, Module.new)
        Object.const_get(:PrimitiveResolverTestNamespace).const_set(:CustomType, Class.new)

        refute PrimitiveResolver.handles?("PrimitiveResolverTestNamespace::CustomType")
      ensure
        Object.send(:remove_const, :PrimitiveResolverTestNamespace) if Object.const_defined?(:PrimitiveResolverTestNamespace)
        if original_namespace && !Object.const_defined?(:PrimitiveResolverTestNamespace)
          Object.const_set(:PrimitiveResolverTestNamespace, original_namespace)
        end
        Object.const_set(:Date, original_date) if original_date && !Object.const_defined?(:Date)
        Object.const_set(:DateTime, original_datetime) if original_datetime && !Object.const_defined?(:DateTime)
      end
    end
  end
end
