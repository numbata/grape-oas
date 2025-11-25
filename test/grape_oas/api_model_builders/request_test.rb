# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestTest < Minitest::Test
      DummyRoute = Struct.new(:options, :path, :settings)

      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_builds_request_body_from_contract_hash
        contract = Struct.new(:to_h).new({ filter: [{ field: "f", value: "v" }], sort: "name" })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body
        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "filter"
        assert_equal "array", schema.properties["filter"].type
      end

      def test_contract_nil_value_sets_nullable
        contract = Struct.new(:to_h).new({ note: nil })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema
        note = schema.properties["note"]

        assert note.nullable
      end

      def test_request_body_and_content_extensions_from_documentation
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = {
          "x-req" => "rb",
          content: {
            "application/json" => { "x-ct" => "ct" }
          }
        }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        rb = operation.request_body

        assert_equal "rb", rb.extensions["x-req"]
        mt = rb.media_types.first

        assert_equal "ct", mt.extensions["x-ct"]
      end
    end
  end
end
