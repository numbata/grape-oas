# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateSchemaRefNameConfigTest < Minitest::Test
    module Namespaced
      class UserEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :name, documentation: { type: String }
      end
    end

    class API < Grape::API
      format :json

      params do
        requires :user, type: Namespaced::UserEntity, documentation: { param_type: "body" }
      end
      post "/users", entity: Namespaced::UserEntity do
        {}
      end

      get "/users", entity: Namespaced::UserEntity do
        {}
      end
    end

    def teardown
      GrapeOAS.schema_ref_name = nil
    end

    # === Default-behavior regression guard ===

    def test_oas3_default_ref_names_preserve_double_underscore_mangling
      GrapeOAS.schema_ref_name = nil

      schema = GrapeOAS.generate(app: API, schema_type: :oas3)
      component_keys = schema.dig("components", "schemas").keys
      post_ref = schema.dig("paths", "/users", "post", "requestBody",
                            "content", "application/json", "schema",
                            "properties", "user", "$ref",)
      get_ref = schema.dig("paths", "/users", "get", "responses", "200",
                           "content", "application/json", "schema", "$ref",)

      assert_includes component_keys, "GrapeOAS_GenerateSchemaRefNameConfigTest_Namespaced_UserEntity"
      assert_equal(
        "#/components/schemas/GrapeOAS_GenerateSchemaRefNameConfigTest_Namespaced_UserEntity",
        post_ref,
      )
      assert_equal(
        "#/components/schemas/GrapeOAS_GenerateSchemaRefNameConfigTest_Namespaced_UserEntity",
        get_ref,
      )
    end

    def test_oas2_default_ref_names_preserve_double_underscore_mangling
      GrapeOAS.schema_ref_name = nil

      schema = GrapeOAS.generate(app: API, schema_type: :oas2)
      definition_keys = schema["definitions"].keys

      assert_includes definition_keys, "GrapeOAS_GenerateSchemaRefNameConfigTest_Namespaced_UserEntity"
    end

    # === Custom lambda coverage ===

    def test_oas3_custom_lambda_rewrites_component_schemas_and_refs
      GrapeOAS.schema_ref_name = ->(name) { name.gsub("::", "-") }

      schema = GrapeOAS.generate(app: API, schema_type: :oas3)
      component_keys = schema.dig("components", "schemas").keys
      post_ref = schema.dig("paths", "/users", "post", "requestBody",
                            "content", "application/json", "schema",
                            "properties", "user", "$ref",)
      get_ref = schema.dig("paths", "/users", "get", "responses", "200",
                           "content", "application/json", "schema", "$ref",)

      assert_includes component_keys, "GrapeOAS-GenerateSchemaRefNameConfigTest-Namespaced-UserEntity"
      assert_equal(
        "#/components/schemas/GrapeOAS-GenerateSchemaRefNameConfigTest-Namespaced-UserEntity",
        post_ref,
      )
      assert_equal(
        "#/components/schemas/GrapeOAS-GenerateSchemaRefNameConfigTest-Namespaced-UserEntity",
        get_ref,
      )
    end

    def test_oas2_custom_lambda_rewrites_definition_keys_and_refs
      GrapeOAS.schema_ref_name = ->(name) { name.gsub("::", "-") }

      schema = GrapeOAS.generate(app: API, schema_type: :oas2)
      definition_keys = schema["definitions"].keys
      get_schema = schema.dig("paths", "/users", "get", "responses", "200", "schema")

      assert_includes definition_keys, "GrapeOAS-GenerateSchemaRefNameConfigTest-Namespaced-UserEntity"
      assert_equal(
        "#/definitions/GrapeOAS-GenerateSchemaRefNameConfigTest-Namespaced-UserEntity",
        get_schema["$ref"],
      )
    end

    def test_custom_lambda_receives_canonical_class_name
      received = []
      GrapeOAS.schema_ref_name = lambda do |name|
        received << name
        name.gsub("::", "_")
      end

      GrapeOAS.generate(app: API, schema_type: :oas3)

      assert_includes received, "GrapeOAS::GenerateSchemaRefNameConfigTest::Namespaced::UserEntity"
    end
  end
end
