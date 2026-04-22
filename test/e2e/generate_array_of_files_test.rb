# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Tests how grape-oas serializes an array-of-files parameter
  # (`type: [File]`) across OAS 2.0, 3.0, and 3.1.
  class GenerateArrayOfFilesTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      desc "Bulk upload"
      params do
        requires :files, type: [File]
      end
      post "bulk_upload" do
        {}
      end
    end

    def test_oas2_array_of_files_property
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      body = schema.dig("paths", "/bulk_upload", "post", "parameters").find { |p| p["in"] == "body" }
      ref = body.dig("schema", "$ref")
      files = schema.dig(*ref.delete_prefix("#/").split("/"), "properties", "files")

      assert_equal "array", files["type"]
      assert_equal({ "type" => "file" }, files["items"])
    end

    def test_oas3_array_of_files_property
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      ref = schema.dig("paths", "/bulk_upload", "post", "requestBody", "content", "application/json", "schema", "$ref")
      files = schema.dig(*ref.delete_prefix("#/").split("/"), "properties", "files")

      assert_equal "array", files["type"]
      assert_equal({ "type" => "string", "format" => "binary" }, files["items"])
    end

    def test_oas3_route_uses_request_body
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      op = schema.dig("paths", "/bulk_upload", "post")

      assert op["requestBody"], "/bulk_upload should have a requestBody"
      assert_nil op["parameters"], "/bulk_upload should not emit query/path parameters"
    end

    def test_oas31_array_of_files_property
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas31)
      ref = schema.dig("paths", "/bulk_upload", "post", "requestBody", "content", "application/json", "schema", "$ref")
      files = schema.dig(*ref.delete_prefix("#/").split("/"), "properties", "files")

      assert_equal "array", files["type"]
      assert_equal(
        {
          "type" => "string",
          "contentMediaType" => "application/octet-stream",
          "contentEncoding" => "binary"
        },
        files["items"],
      )
    end
  end
end
