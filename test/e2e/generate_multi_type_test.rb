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
      assert_equal({ "oneOf" => [{ "type" => "string" }, { "type" => "number", "format" => "float" }] }, value_param["schema"])
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
        { "type" => "number", "format" => "float" }
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

    class NestedEntity < Grape::Entity
      expose :name, documentation: { type: String }
    end

    class EntityMultiType < Grape::Entity
      expose :display_name, documentation: { types: [String, NilClass], desc: "Public display name" }
      expose :native_nil, documentation: { types: [String, nil] }
      expose :array_class, documentation: { types: [Array, NilClass] }
      expose :array_literal, documentation: { types: [[String], NilClass] }
      expose :object, documentation: { types: [Hash, NilClass] }
      expose :strict, documentation: { types: [String, NilClass], nullable: false }
      expose :optional_nested, documentation: { types: [NestedEntity, NilClass] }
      expose :required_nested, using: NestedEntity
      expose :legacy_collection, documentation: { type: [String, NilClass], nullable: true }
    end

    class EntityMultiTypeAPI < Grape::API
      format :json
      desc "Get entity", success: EntityMultiType
      get("entity") { {} }
    end

    def test_oas2_entity_multi_types
      properties = entity_properties(:oas2)

      expected = {
        "type" => "string",
        "description" => "Public display name",
        "x-nullable" => true
      }

      assert_equal expected, properties.fetch("display_name")
      assert properties.dig("native_nil", "x-nullable")
      assert_equal "array", properties.dig("array_class", "type")
      assert_equal "string", properties.dig("array_class", "items", "type")
      assert properties.dig("array_class", "x-nullable")
      assert_equal "array", properties.dig("array_literal", "type")
      assert_equal "string", properties.dig("array_literal", "items", "type")
      assert_equal "object", properties.dig("object", "type")
      assert properties.dig("object", "x-nullable")
      refute properties.fetch("strict").key?("x-nullable")
      assert_equal nested_ref(:oas2), properties.dig("optional_nested", "allOf", 0, "$ref")
      assert properties.dig("optional_nested", "x-nullable")
      assert_equal({ "$ref" => nested_ref(:oas2) }, properties.fetch("required_nested"))
      assert_equal "array", properties.dig("legacy_collection", "type")
      assert_equal "string", properties.dig("legacy_collection", "items", "type")
      assert properties.dig("legacy_collection", "x-nullable")
    end

    def test_oas3_entity_multi_types
      properties = entity_properties(:oas3)

      expected = {
        "type" => "string",
        "description" => "Public display name",
        "nullable" => true
      }

      assert_equal expected, properties.fetch("display_name")
      assert properties.dig("native_nil", "nullable")
      assert_equal "array", properties.dig("array_class", "type")
      assert_equal "string", properties.dig("array_class", "items", "type")
      assert properties.dig("array_class", "nullable")
      assert_equal "array", properties.dig("array_literal", "type")
      assert_equal "string", properties.dig("array_literal", "items", "type")
      assert_equal "object", properties.dig("object", "type")
      assert properties.dig("object", "nullable")
      refute properties.fetch("strict").key?("nullable")
      assert_equal nested_ref(:oas3), properties.dig("optional_nested", "anyOf", 0, "allOf", 0, "$ref")
      assert properties.dig("optional_nested", "anyOf", 1, "nullable")
      assert_equal({ "$ref" => nested_ref(:oas3) }, properties.fetch("required_nested"))
      assert_equal "array", properties.dig("legacy_collection", "type")
      assert_equal "string", properties.dig("legacy_collection", "items", "type")
      assert properties.dig("legacy_collection", "nullable")
    end

    def test_oas31_entity_multi_types
      properties = entity_properties(:oas31)
      display_name = properties.fetch("display_name")

      assert_equal %w[string null], display_name["type"]
      assert_equal "Public display name", display_name["description"]
      refute display_name.key?("items")
      refute display_name.key?("nullable")
      assert_equal %w[string null], properties.dig("native_nil", "type")
      assert_equal %w[array null], properties.dig("array_class", "type")
      assert_equal "string", properties.dig("array_class", "items", "type")
      assert_equal %w[array null], properties.dig("array_literal", "type")
      assert_equal "string", properties.dig("array_literal", "items", "type")
      assert_equal %w[object null], properties.dig("object", "type")
      assert_equal "string", properties.dig("strict", "type")
      refute properties.fetch("strict").key?("nullable")
      assert_equal nested_ref(:oas31), properties.dig("optional_nested", "anyOf", 0, "allOf", 0, "$ref")
      assert_equal "null", properties.dig("optional_nested", "anyOf", 1, "type")
      assert_equal({ "$ref" => nested_ref(:oas31) }, properties.fetch("required_nested"))
      assert_equal %w[array null], properties.dig("legacy_collection", "type")
      assert_equal "string", properties.dig("legacy_collection", "items", "type")
    end

    private

    def nested_ref(schema_type)
      prefix = schema_type == :oas2 ? "#/definitions" : "#/components/schemas"
      "#{prefix}/#{NestedEntity.name.gsub("::", "_")}"
    end

    def entity_properties(schema_type)
      schema = GrapeOAS.generate(app: EntityMultiTypeAPI, schema_type: schema_type)
      schemas = schema["definitions"] || schema.dig("components", "schemas")
      schemas.dig(EntityMultiType.name.gsub("::", "_"), "properties")
    end
  end
end
