# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS31SchemaTest < Minitest::Test
      # === $defs and unevaluatedProperties tests ===

      def test_outputs_defs_and_unevaluated_properties
        schema = ApiModel::Schema.new(
          type: "object",
          defs: { "Shared" => { "type" => "string" } },
          unevaluated_properties: false,
        )

        doc = generate_doc_with_schema(schema)
        param_schema = doc["paths"]["/x"]["get"]["parameters"].first["schema"]

        refute param_schema["unevaluatedProperties"]
        assert_equal({ "Shared" => { "type" => "string" } }, param_schema["$defs"])
      end

      # === nullable as type array tests ===

      def test_nullable_becomes_type_array_with_null
        schema = ApiModel::Schema.new(type: "string", nullable: true)

        doc = generate_doc_with_schema(schema)
        param_schema = doc["paths"]["/x"]["get"]["parameters"].first["schema"]

        assert_equal %w[string null], param_schema["type"]
      end

      # === Inline nested object with enum properties ===

      def test_inline_nested_object_with_enum_properties
        inner = ApiModel::Schema.new(type: "string")
        inner.enum = %w[x y]

        outer = ApiModel::Schema.new(type: "object")
        outer.add_property("direction", inner)

        doc = generate_doc_with_schema(outer)
        param_schema = doc["paths"]["/x"]["get"]["parameters"].first["schema"]

        assert_equal %w[x y], param_schema["properties"]["direction"]["enum"]
      end

      # === Inline nested object with minimum/maximum ===

      def test_inline_nested_object_with_min_max
        inner = ApiModel::Schema.new(type: "integer")
        inner.minimum = -2
        inner.maximum = 2

        outer = ApiModel::Schema.new(type: "object")
        outer.add_property("offset", inner)

        doc = generate_doc_with_schema(outer)
        param_schema = doc["paths"]["/x"]["get"]["parameters"].first["schema"]

        offset = param_schema["properties"]["offset"]

        assert_equal(-2, offset["minimum"])
        assert_equal 2, offset["maximum"]
      end

      # === File type normalization (OAS 3.1) ===
      # OAS 3.1 uses JSON Schema content-* keywords instead of the
      # OAS 3.0 `format: binary` convention.

      def test_file_type_becomes_string_with_content_keywords
        schema = ApiModel::Schema.new(type: "file")

        result = OAS31::Schema.new(schema).build

        assert_equal "string", result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
        refute result.key?("format"), "OAS 3.1 should not emit 'format: binary'"
      end

      def test_array_of_files_items_get_content_keywords
        items = ApiModel::Schema.new(type: "file")
        array = ApiModel::Schema.new(type: "array", items: items)

        result = OAS31::Schema.new(array).build

        assert_equal "array", result["type"]
        assert_equal(
          {
            "type" => "string",
            "contentMediaType" => "application/octet-stream",
            "contentEncoding" => "binary"
          },
          result["items"],
        )
      end

      def test_file_typed_property_gets_content_keywords
        file_prop = ApiModel::Schema.new(type: "file")
        object = ApiModel::Schema.new(type: "object")
        object.add_property("avatar", file_prop)

        result = OAS31::Schema.new(object).build

        assert_equal(
          {
            "type" => "string",
            "contentMediaType" => "application/octet-stream",
            "contentEncoding" => "binary"
          },
          result["properties"]["avatar"],
        )
      end

      def test_nullable_file_type_becomes_nullable_string_with_content_keywords
        schema = ApiModel::Schema.new(type: "file", nullable: true)

        result = OAS31::Schema.new(
          schema, nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        ).build

        assert_equal %w[string null], result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
        refute result.key?("format")
      end

      def test_allof_with_file_type_normalizes_to_content_keywords
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "file")

        result = OAS31::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "string", result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
        refute result.key?("format")
      end

      def test_allof_with_file_type_and_explicit_format_drops_format
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "file")
        schema.format = "binary"

        result = OAS31::Schema.new(schema).build

        assert result.key?("allOf")
        assert_equal "string", result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
        refute result.key?("format"), "OAS 3.1 file normalization should remove format even when explicitly set"
      end

      def test_file_type_with_explicit_format_drops_format
        schema = ApiModel::Schema.new(type: "file")
        schema.format = "binary"

        result = OAS31::Schema.new(schema).build

        assert_equal "string", result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
        refute result.key?("format"), "OAS 3.1 file normalization should remove format"
      end

      def test_oneof_with_file_type_normalizes_to_content_keywords
        variant = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(one_of: [variant], type: "file")

        result = OAS31::Schema.new(schema).build

        assert result.key?("oneOf")
        assert_equal "string", result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
      end

      # === Enum normalization under OAS 3.1 (always TYPE_ARRAY) ===

      def test_nullable_integer_enum_normalized_oas31
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = %w[1 2 3]

        result = OAS31::Schema.new(
          schema, nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        ).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, 3], result["enum"]
      end

      def test_allof_nullable_integer_enum_normalized_oas31
        child = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(all_of: [child], type: "integer", nullable: true)
        schema.enum = %w[1 2 3]

        result = OAS31::Schema.new(
          schema, nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        ).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, 3], result["enum"]
      end

      def test_nullable_integer_enum_preserves_nil_oas31
        schema = ApiModel::Schema.new(type: "integer", nullable: true)
        schema.enum = [1, 2, nil]

        result = OAS31::Schema.new(
          schema, nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        ).build

        assert_equal %w[integer null], result["type"]
        assert_equal [1, 2, nil], result["enum"]
      end

      def test_anyof_with_nullable_file_type_normalizes
        variant = ApiModel::Schema.new(type: "object")
        schema = ApiModel::Schema.new(any_of: [variant], type: "file", nullable: true)

        result = OAS31::Schema.new(
          schema, nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        ).build

        assert result.key?("anyOf")
        assert_equal %w[string null], result["type"]
        assert_equal "application/octet-stream", result["contentMediaType"]
        assert_equal "binary", result["contentEncoding"]
      end

      private

      def generate_doc_with_schema(schema)
        api = ApiModel::API.new(title: "t", version: "v")
        path = ApiModel::Path.new(template: "/x")
        op = ApiModel::Operation.new(http_method: :get,
                                     parameters: [ApiModel::Parameter.new(
                                       location: "query", name: "q", schema: schema,
                                     )],)
        path.add_operation(op)
        api.add_path(path)
        Exporter::OAS31Schema.new(api_model: api).generate
      end
    end
  end
end
