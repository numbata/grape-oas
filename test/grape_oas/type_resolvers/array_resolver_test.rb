# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class ArrayResolverTest < Minitest::Test
      # Mock constrained Dry::Type — has .type but no .primitive
      class MockConstrainedDryType
        attr_reader :type

        def initialize(type)
          @type = type
        end
      end

      # Mock Dry::Type with .primitive
      class MockDryType
        attr_reader :primitive, :meta

        def initialize(primitive:, meta: {})
          @primitive = primitive
          @meta = meta
        end
      end

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

      def test_does_not_handle_multi_type_notation
        refute ArrayResolver.handles?("[String, Integer]")
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

      def test_builds_array_of_dates_with_date_format_when_date_constant_resolves
        require "date"

        schema = ArrayResolver.build_schema("[Date]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::STRING, schema.items.type
        assert_equal "date", schema.items.format
      end

      def test_builds_array_of_datetimes_with_date_time_format_when_date_constant_resolves
        require "date"

        schema = ArrayResolver.build_schema("[DateTime]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::STRING, schema.items.type
        assert_equal "date-time", schema.items.format
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

      # === Constrained Dry::Type as array item ===

      def test_builds_array_of_constrained_dry_type
        # A constrained Dry type wraps the actual type — .primitive is on the inner type,
        # not on the constrained wrapper. ArrayResolver must unwrap before accessing primitive.
        inner_type = MockDryType.new(primitive: Integer)
        constrained = MockConstrainedDryType.new(inner_type)

        # Define a real constant so resolve_class can find it via Object.const_get
        self.class.const_set(:ConstrainedAge, constrained)

        schema = ArrayResolver.build_schema("[#{self.class.name}::ConstrainedAge]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::INTEGER, schema.items.type
      ensure
        self.class.send(:remove_const, :ConstrainedAge) if self.class.const_defined?(:ConstrainedAge)
      end

      # === build_schema tests for string_to_schema_type fallback branches ===
      # When resolve_class returns nil, string_to_schema_type infers the type from the name.

      def test_builds_array_of_unresolvable_integer_type_via_string_fallback
        schema = ArrayResolver.build_schema("[Nonexistent::Integer]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::INTEGER, schema.items.type
      end

      def test_builds_array_of_unresolvable_boolean_type_via_string_fallback
        schema = ArrayResolver.build_schema("[Nonexistent::Boolean]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::BOOLEAN, schema.items.type
      end

      def test_builds_array_of_unresolvable_hash_type_via_string_fallback
        schema = ArrayResolver.build_schema("[Nonexistent::Hash]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::OBJECT, schema.items.type
      end

      def test_builds_array_of_unresolvable_array_type_via_string_fallback
        schema = ArrayResolver.build_schema("[Nonexistent::Array]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::ARRAY, schema.items.type
      end

      def test_build_schema_for_bigdecimal_array_when_constant_is_missing
        original_bigdecimal = Object.const_get(:BigDecimal) if Object.const_defined?(:BigDecimal)

        Object.send(:remove_const, :BigDecimal) if Object.const_defined?(:BigDecimal)

        schema = ArrayResolver.build_schema("[BigDecimal]")

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
        assert_equal Constants::SchemaTypes::NUMBER, schema.items.type
        assert_equal "double", schema.items.format
      ensure
        Object.const_set(:BigDecimal, original_bigdecimal) if original_bigdecimal && !Object.const_defined?(:BigDecimal)
      end
    end
  end
end
