# frozen_string_literal: true

require "test_helper"
require "support/oas_validator"

module GrapeOAS
  class GenerateVariantCollectionTest < Minitest::Test
    class CollectionAPI < Grape::API
      format :json

      params do
        requires :ids, type: [Integer, String], documentation: { is_array: true }
        optional :tags, type: Set[Integer, String]
      end
      route %i[get post], :collections do
        {}
      end
    end

    def setup
      skip "Variant collection notation requires Grape >= 3.3" if Gem::Version.new(Grape::VERSION) < Gem::Version.new("3.3")
    end

    def test_variant_collections_in_query_parameters
      %i[oas2 oas3 oas31].each do |version|
        spec = GrapeOAS.generate(app: CollectionAPI, schema_type: version)
        params = spec.dig("paths", "/collections", "get", "parameters")
        ids = params.find { |param| param["name"] == "ids" }
        tags = params.find { |param| param["name"] == "tags" }
        ids = ids.fetch("schema") unless version == :oas2
        tags = tags.fetch("schema") unless version == :oas2

        assert_collection(ids, version)
        assert_collection(tags, version)
        assert tags["uniqueItems"]
        refute ids.key?("uniqueItems")
        assert OASValidator.validate!(spec)
      end
    end

    def test_variant_collections_in_request_body
      %i[oas2 oas3 oas31].each do |version|
        spec = GrapeOAS.generate(app: CollectionAPI, schema_type: version)
        schemas = version == :oas2 ? spec.fetch("definitions") : spec.dig("components", "schemas")
        body = schemas.fetch("post_collections_Request")

        assert_collection(body.dig("properties", "ids"), version)
        assert_collection(body.dig("properties", "tags"), version)
        assert body.dig("properties", "tags", "uniqueItems")
        assert_includes body["required"], "ids"
      end
    end

    private

    def assert_collection(schema, version)
      assert_equal "array", schema["type"]
      items = schema.fetch("items")
      if version == :oas2
        assert_equal({ "type" => "integer", "format" => "int32" }, items)
      else
        assert_equal [{ "type" => "integer", "format" => "int32" }, { "type" => "string" }], items["oneOf"]
      end
    end
  end
end
