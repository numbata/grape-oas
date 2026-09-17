# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class SchemaRefNameCollisionTest < Minitest::Test
      def test_exporters_reject_colliding_schema_reference_names
        api = ApiModel::API.new(title: "Test", version: "1.0")
        api.registered_schemas = [
          ApiModel::Schema.new(canonical_name: "A::B", type: "string"),
          ApiModel::Schema.new(canonical_name: "A_B", type: "integer")
        ]

        [OAS2Schema, OAS30Schema, OAS31Schema].each do |exporter|
          error = assert_raises(ArgumentError) { exporter.new(api_model: api).generate }

          assert_equal(
            'Schema reference name "A_B" is generated for both "A::B" and "A_B"; ' \
            "configure GrapeOAS.schema_ref_name to generate unique names",
            error.message,
          )
        end
      end
    end
  end
end
