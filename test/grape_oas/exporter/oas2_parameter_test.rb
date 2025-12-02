# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2ParameterTest < Minitest::Test
      def test_collection_format_multi_for_array_param
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "statuses",
          schema: schema,
          required: false,
          collection_format: "multi",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        statuses_param = result.find { |p| p["name"] == "statuses" }

        assert_equal "multi", statuses_param["collectionFormat"]
      end

      def test_collection_format_csv_for_array_param
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "integer"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "ids",
          schema: schema,
          required: false,
          collection_format: "csv",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        ids_param = result.find { |p| p["name"] == "ids" }

        assert_equal "csv", ids_param["collectionFormat"]
      end

      def test_collection_format_brackets
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "tags",
          schema: schema,
          required: false,
          collection_format: "brackets",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        tags_param = result.find { |p| p["name"] == "tags" }

        assert_equal "brackets", tags_param["collectionFormat"]
      end

      def test_invalid_collection_format_ignored
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "items",
          schema: schema,
          required: false,
          collection_format: "invalid",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        items_param = result.find { |p| p["name"] == "items" }

        refute items_param.key?("collectionFormat")
      end

      def test_no_collection_format_for_non_array
        schema = ApiModel::Schema.new(type: "string")
        param = ApiModel::Parameter.new(
          location: "query",
          name: "name",
          schema: schema,
          required: false,
          collection_format: "multi",
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        name_param = result.find { |p| p["name"] == "name" }

        refute name_param.key?("collectionFormat")
      end

      def test_no_collection_format_when_nil
        schema = ApiModel::Schema.new(
          type: "array",
          items: ApiModel::Schema.new(type: "string"),
        )
        param = ApiModel::Parameter.new(
          location: "query",
          name: "values",
          schema: schema,
          required: false,
        )
        operation = ApiModel::Operation.new(
          http_method: "get",
          parameters: [param],
        )

        result = OAS2::Parameter.new(operation).build

        values_param = result.find { |p| p["name"] == "values" }

        refute values_param.key?("collectionFormat")
      end
    end
  end
end
