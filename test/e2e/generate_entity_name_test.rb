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

  # Tests that entity_name returning nil or empty string falls back to class name
  class GenerateEntityNameEdgeCasesTest < Minitest::Test
    class NilNameEntity < Grape::Entity
      expose :id, documentation: { type: Integer }

      def self.entity_name
        nil
      end
    end

    class EmptyNameEntity < Grape::Entity
      expose :id, documentation: { type: Integer }

      def self.entity_name
        ""
      end
    end

    class NilNameAPI < Grape::API
      format :json

      desc "Get item" do
        success NilNameEntity
      end
      get "/nil-name" do
        {}
      end
    end

    class EmptyNameAPI < Grape::API
      format :json

      desc "Get item" do
        success EmptyNameEntity
      end
      get "/empty-name" do
        {}
      end
    end

    # entity_name returning nil should fall back to class name, not produce nil canonical_name
    def test_oas3_nil_entity_name_falls_back_to_class_name
      schema = GrapeOAS.generate(app: NilNameAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert schemas, "Expected components/schemas to be present"
      refute schemas.key?(""), "Schema key should not be empty string"
      refute schemas.keys.any?(&:nil?), "Schema key should not be nil"

      # Should fall back to mangled class name
      nil_name_key = schemas.keys.find { |k| k.include?("NilName") }

      assert nil_name_key, "Expected a schema key derived from class name for NilNameEntity"
    end

    # entity_name returning empty string should fall back to class name
    def test_oas3_empty_entity_name_falls_back_to_class_name
      schema = GrapeOAS.generate(app: EmptyNameAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert schemas, "Expected components/schemas to be present"
      refute schemas.key?(""), "Schema key should not be empty string"

      empty_name_key = schemas.keys.find { |k| k.include?("EmptyName") }

      assert empty_name_key, "Expected a schema key derived from class name for EmptyNameEntity"
    end

    # OAS3: $ref should not point to empty schema name
    def test_oas3_empty_entity_name_ref_is_valid
      schema = GrapeOAS.generate(app: EmptyNameAPI, schema_type: :oas3)
      response_schema = schema.dig(
        "paths", "/empty-name", "get", "responses", "200", "content", "application/json", "schema",
      )

      assert response_schema, "Expected response schema to be present"
      ref = response_schema["$ref"] || response_schema.dig("allOf", 0, "$ref")

      assert ref, "Expected a $ref in the response schema"
      refute_equal "#/components/schemas/", ref, "$ref must not point to empty schema name"
    end
  end

  # Tests that entity_name is respected on child entities in inheritance hierarchies
  class GenerateEntityNameInheritanceTest < Minitest::Test
    class AnimalEntity < Grape::Entity
      expose :species, documentation: {
        type: String,
        is_discriminator: true,
        required: true
      }
      expose :name, documentation: { type: String }

      def self.entity_name
        "Animal"
      end
    end

    class CatEntity < AnimalEntity
      expose :indoor, documentation: { type: "Boolean" }

      def self.entity_name
        "Cat"
      end
    end

    class DogEntity < AnimalEntity
      expose :breed, documentation: { type: String }
    end

    class InheritanceAPI < Grape::API
      format :json

      desc "Get animal" do
        success AnimalEntity
      end
      get "/animals/:id" do
        {}
      end

      desc "Get cat" do
        success CatEntity
      end
      get "/cats/:id" do
        {}
      end

      desc "Get dog" do
        success DogEntity
      end
      get "/dogs/:id" do
        {}
      end
    end

    # Child entity with entity_name should use it as schema key, not class name
    def test_oas3_child_entity_uses_entity_name_as_schema_key
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert schemas, "Expected components/schemas to be present"
      assert_includes schemas.keys, "Cat",
                      "Expected schema key 'Cat' from entity_name, got: #{schemas.keys.inspect}"
    end

    # Parent entity with entity_name should use it as schema key
    def test_oas3_parent_entity_uses_entity_name_as_schema_key
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      assert_includes schemas.keys, "Animal",
                      "Expected schema key 'Animal' from entity_name, got: #{schemas.keys.inspect}"
    end

    # allOf $ref in child should point to parent's entity_name
    def test_oas3_child_allof_ref_uses_parent_entity_name
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      cat_schema = schemas["Cat"]

      assert cat_schema, "Expected 'Cat' schema to exist"

      all_of = cat_schema["allOf"]

      assert all_of, "Expected Cat to use allOf for inheritance"
      assert_equal "#/components/schemas/Animal", all_of[0]["$ref"],
                   "allOf $ref should point to parent's entity_name 'Animal'"
    end

    # Child without its own entity_name falls back to class name and gets
    # its own schema with child-specific properties preserved.
    def test_oas3_child_without_entity_name_uses_class_name
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas3)
      schemas = schema.dig("components", "schemas")

      dog_key = schemas.keys.find { |k| k.include?("Dog") }

      assert dog_key, "Expected a schema key for DogEntity"
      refute_equal "Animal", dog_key,
                   "Child without own entity_name must not collide with parent"

      dog_schema = schemas[dog_key]
      all_of = dog_schema["allOf"]

      assert all_of, "Expected DogEntity to use allOf for inheritance"
      assert_equal "#/components/schemas/Animal", all_of[0]["$ref"]

      child_props = all_of[1]["properties"]

      assert child_props&.key?("breed"), "DogEntity's own 'breed' property must be present"
    end

    # OAS2: same behavior for inheritance with entity_name
    def test_oas2_child_entity_uses_entity_name_as_definition_key
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas2)
      definitions = schema["definitions"]

      assert definitions, "Expected definitions to be present"
      assert_includes definitions.keys, "Cat",
                      "Expected definition key 'Cat' from entity_name, got: #{definitions.keys.inspect}"
    end

    def test_oas2_child_allof_ref_uses_parent_entity_name
      schema = GrapeOAS.generate(app: InheritanceAPI, schema_type: :oas2)
      definitions = schema["definitions"]

      cat_schema = definitions["Cat"]

      assert cat_schema, "Expected 'Cat' definition to exist"

      all_of = cat_schema["allOf"]

      assert all_of, "Expected Cat to use allOf for inheritance"
      assert_equal "#/definitions/Animal", all_of[0]["$ref"],
                   "allOf $ref should point to parent's entity_name 'Animal'"
    end
  end
end
