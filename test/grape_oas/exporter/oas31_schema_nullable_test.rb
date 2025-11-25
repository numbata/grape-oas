# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS31SchemaNullableTest < Minitest::Test
      def test_nullable_becomes_type_array_with_null
        schema = ApiModel::Schema.new(type: "string", nullable: true)
        built = Exporter::OAS31Schema.new(api_model: dummy_api(schema)).generate
        param_schema = built["paths"]["/x"]["get"]["parameters"].first["schema"]

        assert_equal %w[string null], param_schema["type"]
      end

      private

      def dummy_api(schema)
        api = ApiModel::API.new(title: "t", version: "v")
        path = ApiModel::Path.new(template: "/x")
        op = ApiModel::Operation.new(http_method: :get,
                                     parameters: [ApiModel::Parameter.new(
                                       location: "query", name: "q", schema: schema,
                                     )],)
        path.add_operation(op)
        api.add_path(path)
        api
      end
    end
  end
end
