# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2ResponseTest < Minitest::Test
      def test_includes_headers_and_examples
        schema = ApiModel::Schema.new(type: "string")
        media = ApiModel::MediaType.new(mime_type: "application/json", schema: schema,
                                        examples: { "application/json" => { foo: "bar" } },)
        resp = ApiModel::Response.new(http_status: "200", description: "OK", media_types: [media],
                                      headers: [{ name: "X-Trace", schema: { "type" => "string" } }],)

        result = Exporter::OAS2::Response.new([resp]).build

        assert_equal "OK", result["200"]["description"]
        assert_equal({ "X-Trace" => { "type" => "string" } }, result["200"]["headers"])
        assert_equal({ "application/json" => { foo: "bar" } }, result["200"]["examples"])
      end
    end
  end
end
