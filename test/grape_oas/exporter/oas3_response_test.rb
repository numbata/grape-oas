# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3ResponseTest < Minitest::Test
      def test_includes_headers_and_examples
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema, examples: { foo: "bar" })
        resp = ApiModel::Response.new(http_status: "200", description: "OK", media_types: [media],
                                      headers: [{ name: "X-Trace", schema: { "schema" => { "type" => "string" } } }],)

        result = Exporter::OAS3::Response.new([resp]).build

        assert_equal "OK", result["200"]["description"]
        assert_equal({ "X-Trace" => { "schema" => { "type" => "string" } } }, result["200"]["headers"])
        content = result["200"]["content"]["application/json"]

        assert_equal "string", content["schema"]["type"]
        assert_equal({ foo: "bar" }, content["examples"])
      end
    end
  end
end
