# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS31DefsTest < Minitest::Test
      def test_outputs_defs_and_unevaluated_properties
        schema = ApiModel::Schema.new(
          type: "object",
          defs: { "Shared" => { "type" => "string" } },
          unevaluated_properties: false,
        )
        path = ApiModel::Path.new(template: "/x")
        op = ApiModel::Operation.new(http_method: :get,
                                     parameters: [ApiModel::Parameter.new(
                                       location: "query", name: "q", schema: schema,
                                     )],)
        api = ApiModel::API.new(title: "t", version: "v")
        api.add_path(path)
        path.add_operation(op)

        doc = Exporter::OAS31Schema.new(api_model: api).generate
        param_schema = doc["paths"]["/x"]["get"]["parameters"].first["schema"]

        refute param_schema["unevaluatedProperties"]
        assert_equal({ "Shared" => { "type" => "string" } }, param_schema["$defs"])
      end
    end
  end
end
