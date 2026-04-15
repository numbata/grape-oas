# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Tests that grape-oas respects the entity_name method optionally defined on
  # Grape::Entity subclasses. When present, entity_name should be used as the
  # schema definition key (and $ref target) instead of the mangled Ruby class name.
  class GenerateEntityNameTest < Minitest::Test
    class UserEntity < Grape::Entity
      expose :id, documentation: { type: Integer, desc: "User ID" }
      expose :name, documentation: { type: String, desc: "Full name" }

      def self.entity_name
        "UserResponse"
      end
    end

    class PostEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :title, documentation: { type: String }
      expose :author, using: UserEntity, documentation: { type: UserEntity }
    end

    class SampleAPI < Grape::API
      format :json

      desc "Get a user" do
        success UserEntity
      end
      get "/users/:id" do
        {}
      end

      desc "Get a post" do
        success PostEntity
      end
      get "/posts/:id" do
        {}
      end

      desc "List users" do
        success UserEntity
        detail "Returns array of users"
      end
      get "/users" do
        {}
      end
    end

    # OAS3: schema key in components/schemas should be the entity_name value
    def test_oas3_uses_entity_name_as_schema_key
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert schemas, "Expected components/schemas to be present"
      assert_includes schemas.keys, "UserResponse",
                      "Expected schema key 'UserResponse' from entity_name, got: #{schemas.keys.inspect}"
      refute_includes schemas.keys, "GrapeOAS_GenerateEntityNameTest_UserEntity",
                      "Schema key should not be the mangled Ruby class name"
    end

    # OAS3: $ref in response should point to the entity_name
    def test_oas3_ref_uses_entity_name
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      response_schema = schema.dig(
        "paths", "/users/{id}", "get", "responses", "200", "content", "application/json", "schema",
      )

      assert response_schema, "Expected response schema to be present"
      ref = response_schema["$ref"] || response_schema.dig("allOf", 0, "$ref")

      assert ref, "Expected a $ref in the response schema, got: #{response_schema.inspect}"
      assert_equal "#/components/schemas/UserResponse", ref
    end

    # OAS3: entity without entity_name should still use the mangled class name
    def test_oas3_entity_without_entity_name_uses_class_name
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert schemas, "Expected components/schemas to be present"
      post_key = schemas.keys.find { |k| k.include?("Post") }

      assert post_key, "Expected a schema key for PostEntity"
      refute_equal "PostEntity", post_key, "Unqualified class name is not expected as-is"
    end

    # OAS3: nested reference (PostEntity referencing UserEntity) should also use entity_name
    def test_oas3_nested_ref_uses_entity_name
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      post_key = schemas.keys.find { |k| k.include?("Post") }

      assert post_key, "Expected a schema key for PostEntity"

      author_prop = schemas.dig(post_key, "properties", "author")

      assert author_prop, "Expected 'author' property in PostEntity schema"

      ref = author_prop["$ref"] || author_prop.dig("allOf", 0, "$ref")

      assert ref, "Expected a $ref for author property, got: #{author_prop.inspect}"
      assert_equal "#/components/schemas/UserResponse", ref,
                   "Nested $ref should use entity_name 'UserResponse'"
    end

    # OAS2: schema key in definitions should be the entity_name value
    def test_oas2_uses_entity_name_as_definition_key
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      definitions = schema["definitions"]

      assert definitions, "Expected definitions to be present"
      assert_includes definitions.keys, "UserResponse",
                      "Expected definition key 'UserResponse' from entity_name, got: #{definitions.keys.inspect}"
      refute_includes definitions.keys, "GrapeOAS_GenerateEntityNameTest_UserEntity",
                      "Definition key should not be the mangled Ruby class name"
    end

    # OAS2: $ref in response should point to the entity_name
    def test_oas2_ref_uses_entity_name
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      response_schema = schema.dig("paths", "/users/{id}", "get", "responses", "200", "schema")

      assert response_schema, "Expected response schema to be present"
      ref = response_schema["$ref"] || response_schema.dig("allOf", 0, "$ref")

      assert ref, "Expected a $ref in the response schema, got: #{response_schema.inspect}"
      assert_equal "#/definitions/UserResponse", ref
    end
  end
end
