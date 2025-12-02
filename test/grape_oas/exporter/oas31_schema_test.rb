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
