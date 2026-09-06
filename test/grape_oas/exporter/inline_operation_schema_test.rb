# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class InlineOperationSchemaTest < Minitest::Test
      def test_oas31_inline_file_schemas_use_content_keywords
        schema = ApiModel::Schema.new(type: "file")

        inline_schemas(OAS31Schema, schema).each do |rendered|
          assert_equal "string", rendered["type"]
          assert_equal "application/octet-stream", rendered["contentMediaType"]
          assert_equal "binary", rendered["contentEncoding"]
          refute rendered.key?("format")
        end
      end

      def test_oas3_inline_file_schemas_keep_binary_format
        inline_schemas(OAS3Schema, ApiModel::Schema.new(type: "file")).each do |rendered|
          assert_equal({ "type" => "string", "format" => "binary" }, rendered)
        end
      end

      def test_oas31_inline_nested_schemas_use_examples_and_null_unions
        schema = ApiModel::Schema.new(type: "array",
                                      items: ApiModel::Schema.new(type: "boolean", nullable: true, examples: false),)

        inline_schemas(OAS31Schema, schema).each do |rendered|
          assert_equal [false], rendered.dig("items", "examples")
          assert_equal %w[boolean null], rendered.dig("items", "type")
          refute rendered["items"].key?("example")
          refute rendered["items"].key?("nullable")
        end
      end

      def test_oas3_inline_nested_schemas_keep_example_and_nullable
        schema = ApiModel::Schema.new(type: "array",
                                      items: ApiModel::Schema.new(type: "boolean", nullable: true, examples: false),)

        inline_schemas(OAS3Schema, schema).each do |rendered|
          assert rendered["items"].key?("example")
          refute rendered.dig("items", "example")
          assert rendered.dig("items", "nullable")
          refute rendered["items"].key?("examples")
        end
      end

      private

      def inline_schemas(exporter, schema)
        api = ApiModel::API.new(title: "Inline schemas", version: "1")
        media_type = ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
        operation = ApiModel::Operation.new(
          http_method: :post,
          parameters: [ApiModel::Parameter.new(name: "value", location: "query", schema: schema)],
          request_body: ApiModel::RequestBody.new(media_types: [media_type]),
          responses: [ApiModel::Response.new(http_status: 200, description: "OK", media_types: [media_type])],
        )
        path = ApiModel::Path.new(template: "/inline")
        path.add_operation(operation)
        api.add_path(path)
        document = exporter.new(api_model: api).generate
        rendered = document.dig("paths", "/inline", "post")

        [
          rendered["parameters"].first["schema"],
          rendered.dig("requestBody", "content", "application/json", "schema"),
          rendered.dig("responses", "200", "content", "application/json", "schema")
        ]
      end
    end
  end
end
