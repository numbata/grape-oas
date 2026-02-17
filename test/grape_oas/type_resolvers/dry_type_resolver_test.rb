# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module TypeResolvers
    class DryTypeResolverTest < Minitest::Test
      # Mock Dry::Type for testing
      class MockDryType
        attr_reader :primitive, :meta

        def initialize(primitive:, meta: {})
          @primitive = primitive
          @meta = meta
        end
      end

      class MockNamedDryType < MockDryType
        attr_reader :name

        def initialize(name:, primitive:, meta: {})
          super(primitive: primitive, meta: meta)
          @name = name
        end
      end

      # Mock Dry::Type with enum values
      class MockEnumDryType < MockDryType
        attr_reader :values

        def initialize(primitive:, values:, meta: {})
          super(primitive: primitive, meta: meta)
          @values = values
        end
      end

      # Mock Dry::Type that is optional
      class MockOptionalDryType < MockDryType
        def optional?
          true
        end
      end

      # Mock constrained type (has .type method to get inner type)
      class MockConstrainedDryType
        attr_reader :type

        def initialize(type)
          @type = type
        end
      end

      class NotDryTypeWithTypeMethod
        def type
          String
        end
      end

      # === handles? tests ===

      def test_handles_object_with_primitive_method
        dry_type = MockDryType.new(primitive: String)

        assert DryTypeResolver.handles?(dry_type)
      end

      def test_handles_object_with_type_method
        inner_type = MockDryType.new(primitive: String)
        constrained = MockConstrainedDryType.new(inner_type)

        assert DryTypeResolver.handles?(constrained)
      end

      def test_does_not_handle_non_dry_object_with_type_method
        refute DryTypeResolver.handles?(NotDryTypeWithTypeMethod.new)
      end

      def test_does_not_handle_regular_string
        refute DryTypeResolver.handles?("String")
      end

      def test_does_not_handle_regular_class
        refute DryTypeResolver.handles?(String)
      end

      def test_does_not_handle_array_notation
        # Arrays are handled by ArrayResolver
        refute DryTypeResolver.handles?("[String]")
      end

      # === build_schema tests ===

      def test_builds_schema_for_string_primitive
        dry_type = MockDryType.new(primitive: String)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::STRING, schema.type
      end

      def test_builds_schema_for_integer_primitive
        dry_type = MockDryType.new(primitive: Integer)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::INTEGER, schema.type
      end

      def test_builds_schema_for_float_primitive
        dry_type = MockDryType.new(primitive: Float)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::NUMBER, schema.type
      end

      def test_builds_schema_for_boolean_primitive_true_class
        dry_type = MockDryType.new(primitive: TrueClass)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::BOOLEAN, schema.type
      end

      def test_builds_schema_for_boolean_primitive_false_class
        dry_type = MockDryType.new(primitive: FalseClass)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::BOOLEAN, schema.type
      end

      def test_builds_schema_for_hash_primitive
        dry_type = MockDryType.new(primitive: Hash)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::OBJECT, schema.type
      end

      def test_builds_schema_for_array_primitive
        dry_type = MockDryType.new(primitive: Array)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal Constants::SchemaTypes::ARRAY, schema.type
      end

      # === Format extraction tests ===

      def test_extracts_format_from_meta
        dry_type = MockDryType.new(primitive: String, meta: { format: "uuid" })

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal "uuid", schema.format
      end

      def test_infers_uuid_format_from_name_suffix
        dry_type = MockNamedDryType.new(name: "MyApp::Types::UUID", primitive: String)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal "uuid", schema.format
      end

      def test_does_not_infer_date_format_from_substring
        dry_type = MockNamedDryType.new(name: "MyApp::Types::DateRange", primitive: String)

        schema = DryTypeResolver.build_schema(dry_type)

        assert_nil schema.format
      end

      # === Enum tests ===

      def test_extracts_enum_values
        dry_type = MockEnumDryType.new(
          primitive: String,
          values: %w[draft published archived],
        )

        schema = DryTypeResolver.build_schema(dry_type)

        assert_equal %w[draft published archived], schema.enum
      end

      # === Nullable tests ===

      def test_marks_optional_types_as_nullable
        dry_type = MockOptionalDryType.new(primitive: String)

        schema = DryTypeResolver.build_schema(dry_type)

        assert schema.nullable
      end

      # === build_schema with string input ===

      def test_builds_schema_from_string_that_resolves_to_dry_type
        # When build_schema receives a string (not a Dry::Type object),
        # it should resolve the class via resolve_class and build the schema.
        dry_type = MockDryType.new(primitive: String, meta: { format: "uuid" })

        DryTypeResolver.stub(:resolve_class, ->(_name) { dry_type }) do
          schema = DryTypeResolver.build_schema("SomeModule::UUID")

          assert_equal Constants::SchemaTypes::STRING, schema.type
          assert_equal "uuid", schema.format
        end
      end

      # === Constrained type unwrapping ===

      def test_unwraps_constrained_type_to_get_primitive
        inner_type = MockDryType.new(primitive: Integer)
        constrained = MockConstrainedDryType.new(inner_type)

        schema = DryTypeResolver.build_schema(constrained)

        assert_equal Constants::SchemaTypes::INTEGER, schema.type
      end
    end
  end
end
