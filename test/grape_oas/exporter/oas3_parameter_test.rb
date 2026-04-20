# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3ParameterTest < Minitest::Test
      def test_description_not_duplicated_in_schema
        schema = ApiModel::Schema.new(type: "integer", description: "Number of items")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "size",
          schema: schema,
          required: false,
          description: "Number of items",
        )
        operation = ApiModel::Operation.new(http_method: "get", parameters: [param])

        result = OAS3::Parameter.new(operation).build
        size_param = result.first

        assert_equal "Number of items", size_param["description"]
        refute size_param["schema"].key?("description"),
               "schema should not carry a description for in: query parameters"
      end

      def test_description_hoisted_from_schema_when_param_description_missing
        schema = ApiModel::Schema.new(type: "integer", description: "Schema-only desc")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "size",
          schema: schema,
          required: false,
          description: nil,
        )
        operation = ApiModel::Operation.new(http_method: "get", parameters: [param])

        result = OAS3::Parameter.new(operation).build
        size_param = result.first

        assert_equal "Schema-only desc", size_param["description"]
        refute size_param["schema"].key?("description")
      end

      def test_no_description_anywhere_when_neither_source_sets_it
        schema = ApiModel::Schema.new(type: "integer")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "size",
          schema: schema,
          required: false,
        )
        operation = ApiModel::Operation.new(http_method: "get", parameters: [param])

        result = OAS3::Parameter.new(operation).build
        size_param = result.first

        refute size_param.key?("description")
        refute size_param["schema"].key?("description")
      end
    end
  end
end
