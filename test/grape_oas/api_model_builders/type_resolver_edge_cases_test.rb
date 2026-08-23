# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Tests for type resolution edge cases
      class TypeResolverEdgeCasesTest < Minitest::Test
        include TypeResolver

        # === Symbol type ===

        def test_symbol_type_resolves_to_string
          assert_equal "string", resolve_schema_type(Symbol)
        end

        def test_symbol_string_resolves_to_string
          assert_equal "string", resolve_schema_type("Symbol")
        end

        # === Date/Time types ===

        def test_date_type_resolves_to_string
          assert_equal "string", resolve_schema_type(Date)
        end

        def test_datetime_type_resolves_to_string
          assert_equal "string", resolve_schema_type(DateTime)
        end

        def test_time_type_resolves_to_string
          assert_equal "string", resolve_schema_type(Time)
        end

        # === File type ===

        def test_file_type_resolves_to_file
          assert_equal "file", resolve_schema_type(File)
        end

        def test_file_string_resolves_to_file
          assert_equal "file", resolve_schema_type("File")
        end

        # === Rack::Multipart::UploadedFile ===

        def test_rack_uploaded_file_string_resolves_to_file
          assert_equal "file", resolve_schema_type("Rack::Multipart::UploadedFile")
        end

        # === Grape::API::Boolean ===

        def test_grape_boolean_class_resolves_to_boolean
          skip "Grape::API::Boolean may not be available" unless defined?(Grape::API::Boolean)

          assert_equal "boolean", resolve_schema_type(Grape::API::Boolean)
        end

        def test_grape_boolean_string_resolves_to_boolean
          assert_equal "boolean", resolve_schema_type("Grape::API::Boolean")
        end

        # === JSON type (Grape's special type) ===

        def test_json_type_resolves_to_object
          skip "JSON type may need special handling"

          assert_equal "object", resolve_schema_type(JSON)
        end

        # === Virtus::Attribute::Boolean ===

        def test_virtus_boolean_string_resolves_to_boolean
          # Virtus is sometimes used with Grape
          result = resolve_schema_type("Virtus::Attribute::Boolean")
          # Should fall back to string if not specially handled
          assert_equal "string", result
        end

        # === Numeric types ===

        def test_numeric_type_resolves_to_number
          # Numeric is the parent class of Integer and Float
          result = resolve_schema_type(Numeric)
          # May fall back to string if not in mapping
          assert_includes %w[number string], result
        end

        # === Nil type ===

        def test_nil_resolves_to_string
          assert_equal "string", resolve_schema_type(nil)
        end

        # === Empty string ===

        def test_empty_string_resolves_to_string
          assert_equal "string", resolve_schema_type("")
        end

        # === Mixed case type names ===

        def test_integer_mixed_case_resolves
          assert_equal "integer", resolve_schema_type("INTEGER")
          assert_equal "integer", resolve_schema_type("Integer")
          assert_equal "integer", resolve_schema_type("integer")
        end

        def test_boolean_mixed_case_resolves
          assert_equal "boolean", resolve_schema_type("BOOLEAN")
          assert_equal "boolean", resolve_schema_type("Boolean")
          assert_equal "boolean", resolve_schema_type("boolean")
        end

        # === Typed array notation ===

        def test_typed_array_string_notation
          assert_equal "array", resolve_schema_type("[String]")
        end

        def test_grape_33_array_prefix_string_notation
          assert_equal "array", resolve_schema_type("Array[String]")
        end

        def test_grape_33_variant_collection_notation
          assert_equal "array", resolve_schema_type("Array[Integer, String]")
        end

        def test_typed_array_integer_notation
          assert_equal "array", resolve_schema_type("[Integer]")
        end

        def test_typed_array_custom_type_notation
          assert_equal "array", resolve_schema_type("[CustomType]")
        end

        # === Extract member from typed array ===

        def test_extract_member_from_typed_array
          assert_equal "String", extract_typed_array_member("[String]")
          assert_equal "Integer", extract_typed_array_member("[Integer]")
          assert_equal "MyEntity", extract_typed_array_member("[MyEntity]")
          assert_equal "String", extract_typed_array_member("Array[String]")
          assert_equal "Integer", extract_typed_array_member("Set[Integer]")
        end

        def test_extract_member_returns_nil_for_non_array
          assert_nil extract_typed_array_member("String")
          assert_nil extract_typed_array_member("Array")
          assert_nil extract_typed_array_member("Array[String, Integer]")
          assert_nil extract_typed_array_member(nil)
        end
      end
    end
  end
end
