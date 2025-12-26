# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateGetContractParamsTest < Minitest::Test
    class GetContractAPI < Grape::API
      format :json

      ComplexContract = Dry::Schema.Params do
        required(:id).filled(:integer)
        required(:query).filled(:string)
        optional(:price_min).filled(:integer)
        optional(:price_max).filled(:integer)
        required(:tags).value(:array, min_size?: 1, max_size?: 3).each(:string)
        required(:filters).array(:hash) do
          required(:field).filled(:string)
          required(:value).filled(:string)
          optional(:operator).filled(:string)
          required(:meta).hash do
            required(:source).filled(:string)
            optional(:confidence).filled(:integer)
          end
        end
        optional(:range).hash do
          required(:bounds).hash do
            required(:min).filled(:integer)
            optional(:max).filled(:integer)
          end
        end
      end

      namespace :items do
        desc "Search items with complex filters",
             contract: ComplexContract,
             documentation: {
               params: {
                 filters: { style: "form", explode: true },
                 range: { style: "deepObject", explode: true }
               }
             }
        get ":id/search" do
          { results: [] }
        end
      end
    end

    def test_complex_get_contract_generates_array_parameters
      schema = GrapeOAS.generate(app: GetContractAPI, schema_type: :oas3)
      get_op = schema.dig("paths", "/items/{id}/search", "get")
      parameters = get_op["parameters"]

      id_query_param = parameters.find { |p| p["name"] == "id" && p["in"] == "query" }
      id_path_param = parameters.find { |p| p["name"] == "id" && p["in"] == "path" }

      refute id_query_param, "Should not include id as a query parameter"
      assert id_path_param, "Should include id as a path parameter"

      query_param = parameters.find { |p| p["name"] == "query" }

      assert query_param
      assert query_param["required"]

      tags_param = parameters.find { |p| p["name"] == "tags" }

      assert tags_param, "Should have tags parameter for string array"
      assert_equal "query", tags_param["in"]
      assert_equal "array", tags_param["schema"]["type"]
      assert_equal "string", tags_param.dig("schema", "items", "type")
      assert_equal 1, tags_param["schema"]["minItems"]
      assert_equal 3, tags_param["schema"]["maxItems"]
      assert tags_param["required"]

      filters_param = parameters.find { |p| p["name"] == "filters" }

      assert filters_param, "Should have filters parameter for array"
      assert_equal "query", filters_param["in"]
      assert_equal "array", filters_param["schema"]["type"]
      assert filters_param["required"]
      assert_equal "form", filters_param["style"]
      assert filters_param["explode"]

      filters_item_schema = filters_param.dig("schema", "items")

      assert filters_item_schema, "filters should describe items schema"
      assert_equal "object", filters_item_schema["type"]

      filters_required = filters_item_schema["required"] || []

      assert_includes filters_required, "field"
      assert_includes filters_required, "value"
      assert_includes filters_required, "meta"

      filters_meta = filters_item_schema.dig("properties", "meta")

      assert filters_meta, "filters item should have meta object"
      assert_equal "object", filters_meta["type"]

      filters_meta_required = filters_meta["required"] || []

      assert_includes filters_meta_required, "source"

      bracketed_filter_param = parameters.find { |p| p["name"].start_with?("filters[") }

      refute bracketed_filter_param, "Should not emit bracketed filter params"

      range_param = parameters.find { |p| p["name"] == "range" }

      assert range_param, "Should have range parameter"
      assert_equal "query", range_param["in"]
      assert_equal "object", range_param["schema"]["type"]
      assert_equal "deepObject", range_param["style"]
      assert range_param["explode"]

      bounds_schema = range_param.dig("schema", "properties", "bounds")

      assert bounds_schema, "range should include bounds object"
      assert_includes range_param.dig("schema", "required") || [], "bounds"
      assert_includes bounds_schema["required"] || [], "min"

      bracketed_range_param = parameters.find { |p| p["name"].start_with?("range[") }

      refute bracketed_range_param, "Should not emit bracketed range params"
    end
  end
end
