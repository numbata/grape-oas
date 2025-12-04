# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateMultiTypeTest < Minitest::Test
    class MultiTypeAPI < Grape::API
      format :json

      namespace :items do
        desc "Search items"
        params do
          requires :query, types: [String, Integer], desc: "Search by name or ID"
          optional :value, types: [String, Float], desc: "Value filter"
        end
        get do
          []
        end

        desc "Get item"
        params do
          requires :id, types: [String, Integer]
        end
        get ":id" do
          {}
        end
      end
    end

    def test_oas3_uses_one_of_for_multi_type
      schema = GrapeOAS.generate(app: MultiTypeAPI, schema_type: :oas3)

      params = schema.dig("paths", "/items", "get", "parameters")

      query_param = params.find { |p| p["name"] == "query" }
      value_param = params.find { |p| p["name"] == "value" }

      # query param should have oneOf
      assert_equal({ "oneOf" => [{ "type" => "string" }, { "type" => "integer" }] }, query_param["schema"])
      assert query_param["required"]

      # value param should have oneOf
      assert_equal({ "oneOf" => [{ "type" => "string" }, { "type" => "number" }] }, value_param["schema"])
      refute value_param["required"]
    end

    def test_oas31_uses_one_of_for_multi_type
      schema = GrapeOAS.generate(app: MultiTypeAPI, schema_type: :oas31)

      params = schema.dig("paths", "/items", "get", "parameters")

      query_param = params.find { |p| p["name"] == "query" }

      assert_equal({ "oneOf" => [{ "type" => "string" }, { "type" => "integer" }] }, query_param["schema"])
    end

    def test_oas2_uses_first_type_fallback
      schema = GrapeOAS.generate(app: MultiTypeAPI, schema_type: :oas2)

      params = schema.dig("paths", "/items", "get", "parameters")

      query_param = params.find { |p| p["name"] == "query" }
      value_param = params.find { |p| p["name"] == "value" }

      # OAS2 doesn't support oneOf for parameters, uses first type
      assert_equal "string", query_param["schema"]["type"]
      assert_equal "string", value_param["schema"]["type"]
    end

    def test_multi_type_in_path_parameter
      schema = GrapeOAS.generate(app: MultiTypeAPI, schema_type: :oas3)

      params = schema.dig("paths", "/items/{id}", "get", "parameters")

      id_param = params.find { |p| p["name"] == "id" }

      assert_equal "path", id_param["in"]
      assert_equal({ "oneOf" => [{ "type" => "string" }, { "type" => "integer" }] }, id_param["schema"])
    end

    # === Three types ===

    class ThreeTypeAPI < Grape::API
      format :json

      params do
        requires :mixed, types: [String, Integer, Float]
      end
      get("mixed") { {} }
    end

    def test_oas3_three_types
      schema = GrapeOAS.generate(app: ThreeTypeAPI, schema_type: :oas3)

      params = schema.dig("paths", "/mixed", "get", "parameters")
      mixed_param = params.find { |p| p["name"] == "mixed" }

      expected_one_of = [
        { "type" => "string" },
        { "type" => "integer" },
        { "type" => "number" }
      ]

      assert_equal({ "oneOf" => expected_one_of }, mixed_param["schema"])
    end

    def test_oas2_three_types_uses_first
      schema = GrapeOAS.generate(app: ThreeTypeAPI, schema_type: :oas2)

      params = schema.dig("paths", "/mixed", "get", "parameters")
      mixed_param = params.find { |p| p["name"] == "mixed" }

      # Should use first type (String)
      assert_equal "string", mixed_param["schema"]["type"]
    end

    # === Boolean type ===

    class BooleanTypeAPI < Grape::API
      format :json

      params do
        requires :flag, types: [String, Grape::API::Boolean]
      end
      get("flag") { {} }
    end

    def test_oas3_with_boolean_type
      schema = GrapeOAS.generate(app: BooleanTypeAPI, schema_type: :oas3)

      params = schema.dig("paths", "/flag", "get", "parameters")
      flag_param = params.find { |p| p["name"] == "flag" }

      expected_one_of = [
        { "type" => "string" },
        { "type" => "boolean" }
      ]

      assert_equal({ "oneOf" => expected_one_of }, flag_param["schema"])
    end
  end
end
