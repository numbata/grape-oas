# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3ResponseTest < Minitest::Test
      def test_headers_have_schema_wrapper
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
        resp = ApiModel::Response.new(
          http_status: "200",
          description: "OK",
          media_types: [media],
          headers: [{ name: "X-Trace", schema: { "type" => "string" } }],
        )

        result = Exporter::OAS3::Response.new([resp]).build

        # OAS3 headers must have schema wrapper
        assert_equal({ "schema" => { "type" => "string" } }, result["200"]["headers"]["X-Trace"])
      end

      def test_headers_include_description
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
        resp = ApiModel::Response.new(
          http_status: "200",
          description: "OK",
          media_types: [media],
          headers: [{ name: "X-Request-Id", schema: { "type" => "string" }, description: "Unique request ID" }],
        )

        result = Exporter::OAS3::Response.new([resp]).build

        header = result["200"]["headers"]["X-Request-Id"]

        assert_equal({ "type" => "string" }, header["schema"])
        assert_equal "Unique request ID", header["description"]
      end

      def test_headers_default_to_string_type
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
        resp = ApiModel::Response.new(
          http_status: "200",
          description: "OK",
          media_types: [media],
          headers: [{ name: "X-Token" }],
        )

        result = Exporter::OAS3::Response.new([resp]).build

        assert_equal({ "schema" => { "type" => "string" } }, result["200"]["headers"]["X-Token"])
      end

      def test_named_examples_wrapped_with_value
        schema = ApiModel::Schema.new(type: "object")
        examples = { "success" => { "id" => 1, "name" => "Test" } }
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema, examples: examples)
        resp = ApiModel::Response.new(http_status: "200", description: "OK", media_types: [media])

        result = Exporter::OAS3::Response.new([resp]).build
        content = result["200"]["content"]["application/json"]

        # OAS3 named examples must be wrapped with "value" key
        assert content.key?("examples"), "Should use 'examples' for named examples"
        refute content.key?("example"), "Should not have both 'example' and 'examples'"
        assert_equal({ "id" => 1, "name" => "Test" }, content["examples"]["success"]["value"])
      end

      def test_single_example_not_wrapped
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema, examples: "hello world")
        resp = ApiModel::Response.new(http_status: "200", description: "OK", media_types: [media])

        result = Exporter::OAS3::Response.new([resp]).build
        content = result["200"]["content"]["application/json"]

        # Single non-hash example uses "example" (singular)
        assert content.key?("example"), "Should use 'example' for single value"
        refute content.key?("examples"), "Should not have 'examples' for single value"
        assert_equal "hello world", content["example"]
      end

      def test_examples_already_wrapped_not_double_wrapped
        schema = ApiModel::Schema.new(type: "object")
        # Already properly wrapped example
        examples = { "success" => { "value" => { "id" => 1 }, "summary" => "Success case" } }
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema, examples: examples)
        resp = ApiModel::Response.new(http_status: "200", description: "OK", media_types: [media])

        result = Exporter::OAS3::Response.new([resp]).build
        content = result["200"]["content"]["application/json"]

        # Should not double-wrap
        assert_equal({ "id" => 1 }, content["examples"]["success"]["value"])
      end
    end
  end
end
