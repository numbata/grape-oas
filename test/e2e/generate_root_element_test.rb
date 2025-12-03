# frozen_string_literal: true

require "test_helper"

# Define entity at top level to avoid namespace issues
class RootTestItemEntity < Grape::Entity
  expose :id, documentation: { type: Integer }
  expose :name, documentation: { type: String }
end

class RootTestApiError < Grape::Entity
  expose :code, documentation: { type: Integer }
  expose :message, documentation: { type: String }
end

module GrapeOAS
  class GenerateRootElementTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      # No root wrapping (default)
      desc "Get item without root",
           success: { code: 200, model: RootTestItemEntity }
      get "item" do
        {}
      end

      # Auto root with true - uses underscored entity name
      route_setting :swagger, root: true
      desc "Get item with auto root",
           success: { code: 200, model: RootTestItemEntity }
      get "item_with_root" do
        {}
      end

      # Custom root name
      route_setting :swagger, root: "custom_key"
      desc "Get item with custom root",
           success: { code: 200, model: RootTestItemEntity }
      get "item_with_custom_root" do
        {}
      end

      # Array with root - should pluralize
      route_setting :swagger, root: true
      desc "Get items with root and array",
           is_array: true,
           success: { code: 200, model: RootTestItemEntity }
      get "items_with_root" do
        []
      end

      # Test underscore conversion
      route_setting :swagger, root: true
      desc "Get api error",
           success: { code: 200, model: RootTestApiError }
      get "error" do
        {}
      end
    end

    def test_oas2_no_root_by_default
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      response_schema = schema.dig("paths", "/item", "get", "responses", "200", "schema")

      # Should be a direct reference, not wrapped in object
      assert response_schema.key?("$ref"), "Should be a direct $ref without root"
      refute response_schema.key?("properties"), "Should not have properties wrapper"
    end

    def test_oas2_auto_root_with_true
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      response_schema = schema.dig("paths", "/item_with_root", "get", "responses", "200", "schema")

      assert_equal "object", response_schema["type"], "Should be wrapped in object"
      assert response_schema["properties"].key?("root_test_item"), "Should use underscored entity name as key"
      assert response_schema.dig("properties", "root_test_item", "$ref"), "Inner should be $ref"
    end

    def test_oas2_custom_root_name
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      response_schema = schema.dig("paths", "/item_with_custom_root", "get", "responses", "200", "schema")

      assert_equal "object", response_schema["type"], "Should be wrapped in object"
      assert response_schema["properties"].key?("custom_key"), "Should use custom root name"
    end

    def test_oas2_array_with_root_pluralizes
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      response_schema = schema.dig("paths", "/items_with_root", "get", "responses", "200", "schema")

      assert_equal "object", response_schema["type"], "Should be wrapped in object"
      # NOTE: the entity name is RootTestItemEntity, so the key should be "root_test_items"
      assert response_schema["properties"].key?("root_test_items"), "Should pluralize key for array"
    end

    def test_oas2_underscore_conversion
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      response_schema = schema.dig("paths", "/error", "get", "responses", "200", "schema")

      assert_equal "object", response_schema["type"]
      # RootTestApiError -> root_test_api_error (without Entity suffix)
      assert response_schema["properties"].key?("root_test_api_error"), "Should properly underscore multi-word names"
    end

    def test_oas3_root_wrapping
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)

      response_schema = schema.dig(
        "paths", "/item_with_root", "get", "responses", "200", "content", "application/json", "schema",
      )

      assert_equal "object", response_schema["type"], "Should be wrapped in object"
      assert response_schema["properties"].key?("root_test_item"), "Should use underscored entity name as key"
    end
  end
end
