# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class TypeResolverTest < Minitest::Test
      class TestResolver
        include Concerns::TypeResolver
      end

      def resolver
        @resolver ||= TestResolver.new
      end

      # resolve_schema_type tests

      def test_resolve_schema_type_with_nil
        assert_equal "string", resolver.resolve_schema_type(nil)
      end

      def test_resolve_schema_type_with_ruby_classes
        assert_equal "integer", resolver.resolve_schema_type(Integer)
        assert_equal "number", resolver.resolve_schema_type(Float)
        assert_equal "string", resolver.resolve_schema_type(String)
        assert_equal "boolean", resolver.resolve_schema_type(TrueClass)
        assert_equal "boolean", resolver.resolve_schema_type(FalseClass)
        assert_equal "array", resolver.resolve_schema_type(Array)
        assert_equal "object", resolver.resolve_schema_type(Hash)
      end

      def test_resolve_schema_type_with_string_names
        assert_equal "integer", resolver.resolve_schema_type("integer")
        assert_equal "number", resolver.resolve_schema_type("float")
        assert_equal "string", resolver.resolve_schema_type("string")
        assert_equal "boolean", resolver.resolve_schema_type("boolean")
      end

      def test_resolve_schema_type_with_unknown_type
        assert_equal "string", resolver.resolve_schema_type(Object)
        assert_equal "string", resolver.resolve_schema_type("unknown")
      end

      # build_schema_for_primitive tests

      def test_build_schema_for_array_class
        # This was a bug: case/when didn't match Array === Array
        schema = resolver.build_schema_for_primitive(Array)

        assert_equal "array", schema.type
        assert_equal "string", schema.items.type
      end

      def test_build_schema_for_array_with_member
        schema = resolver.build_schema_for_primitive(Array, member: Integer)

        assert_equal "array", schema.type
        assert_equal "integer", schema.items.type
      end

      def test_build_schema_for_hash_class
        schema = resolver.build_schema_for_primitive(Hash)

        assert_equal "object", schema.type
      end

      def test_build_schema_for_integer_class
        schema = resolver.build_schema_for_primitive(Integer)

        assert_equal "integer", schema.type
      end

      def test_build_schema_for_string_class
        schema = resolver.build_schema_for_primitive(String)

        assert_equal "string", schema.type
      end

      # derive_primitive_and_member tests

      def test_derive_primitive_and_member_with_plain_class
        primitive, member = resolver.derive_primitive_and_member(Integer)

        assert_equal Integer, primitive
        assert_nil member
      end

      def test_derive_primitive_and_member_with_dry_type
        skip "Requires dry-types" unless defined?(Dry::Types)

        int_array = Dry::Types["array"].of(Dry::Types["coercible.integer"])
        primitive, member = resolver.derive_primitive_and_member(int_array)

        assert_equal Array, primitive
        refute_nil member
      end

      # multi_type? tests

      def test_multi_type_with_two_types
        assert resolver.multi_type?("[String, Integer]")
        assert resolver.multi_type?("[String,Integer]")
        assert resolver.multi_type?("[String, Float]")
      end

      def test_multi_type_with_three_types
        assert resolver.multi_type?("[String, Integer, Float]")
      end

      def test_multi_type_with_namespaced_types
        assert resolver.multi_type?("[String, Grape::API::Boolean]")
      end

      def test_multi_type_false_for_single_type_array
        refute resolver.multi_type?("[String]")
        refute resolver.multi_type?("[Integer]")
      end

      def test_multi_type_false_for_non_array_string
        refute resolver.multi_type?("String")
        refute resolver.multi_type?("Integer")
        refute resolver.multi_type?(nil)
      end

      # extract_multi_types tests

      def test_extract_multi_types_with_two_types
        result = resolver.extract_multi_types("[String, Integer]")

        assert_equal %w[String Integer], result
      end

      def test_extract_multi_types_with_three_types
        result = resolver.extract_multi_types("[String, Integer, Float]")

        assert_equal %w[String Integer Float], result
      end

      def test_extract_multi_types_with_namespaced_type
        result = resolver.extract_multi_types("[String, Grape::API::Boolean]")

        assert_equal ["String", "Grape::API::Boolean"], result
      end

      def test_extract_multi_types_nil_for_single_type
        assert_nil resolver.extract_multi_types("[String]")
      end

      def test_extract_multi_types_nil_for_non_array
        assert_nil resolver.extract_multi_types("String")
        assert_nil resolver.extract_multi_types(nil)
      end
    end
  end
end
