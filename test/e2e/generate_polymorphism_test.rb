# frozen_string_literal: true

require "test_helper"
require "json"

# E2E tests for polymorphism (allOf, discriminator) across OAS versions
class GeneratePolymorphismTest < Minitest::Test
  # Define test entities
  module Entities
    class Pet < Grape::Entity
      expose :pet_type, documentation: {
        type: String,
        is_discriminator: true,
        required: true,
        desc: "Type of pet"
      }
      expose :name, documentation: { type: String, required: true }
    end

    class Cat < Pet
      expose :hunting_skill, documentation: {
        type: String,
        desc: "The measured skill for hunting",
        values: %w[clueless lazy adventurous aggressive]
      }
    end

    class Dog < Pet
      expose :breed, documentation: { type: String }
      expose :pack_size, documentation: { type: Integer }
    end
  end

  class TestAPI < Grape::API
    format :json

    desc "Get a pet", entity: Entities::Pet
    get "pets/:id" do
      {}
    end

    desc "Get a cat", entity: Entities::Cat
    get "cats/:id" do
      {}
    end

    desc "Get a dog", entity: Entities::Dog
    get "dogs/:id" do
      {}
    end
  end

  # Schema names include the test class prefix
  PET_SCHEMA_NAME = "GeneratePolymorphismTest_Entities_Pet"
  CAT_SCHEMA_NAME = "GeneratePolymorphismTest_Entities_Cat"
  DOG_SCHEMA_NAME = "GeneratePolymorphismTest_Entities_Dog"

  # === OAS 2.0 Tests ===

  def test_oas2_parent_entity_has_discriminator_string
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas2)

    pet_schema = schema.dig("definitions", PET_SCHEMA_NAME)
    refute_nil pet_schema, "Pet schema should exist"

    # OAS2 discriminator is a simple string
    assert_equal "pet_type", pet_schema["discriminator"]
  end

  def test_oas2_child_entity_has_allof
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas2)

    cat_schema = schema.dig("definitions", CAT_SCHEMA_NAME)
    refute_nil cat_schema, "Cat schema should exist"

    all_of = cat_schema["allOf"]
    refute_nil all_of, "Cat should use allOf"
    assert_equal 2, all_of.length

    # First should be $ref to parent
    assert_equal "#/definitions/#{PET_SCHEMA_NAME}", all_of[0]["$ref"]

    # Second should have child-specific properties
    child_props = all_of[1]["properties"]
    refute_nil child_props
    assert child_props.key?("hunting_skill")
  end

  def test_oas2_dog_entity_has_allof
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas2)

    dog_schema = schema.dig("definitions", DOG_SCHEMA_NAME)
    refute_nil dog_schema

    all_of = dog_schema["allOf"]
    refute_nil all_of

    child_props = all_of[1]["properties"]
    assert child_props.key?("breed")
    assert child_props.key?("pack_size")
  end

  # === OAS 3.0 Tests ===

  def test_oas3_parent_entity_has_discriminator_object
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)
    refute_nil pet_schema, "Pet schema should exist"

    # OAS3 discriminator is an object
    discriminator = pet_schema["discriminator"]
    refute_nil discriminator
    assert_equal "pet_type", discriminator["propertyName"]
  end

  def test_oas3_child_entity_has_allof
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    cat_schema = schema.dig("components", "schemas", CAT_SCHEMA_NAME)
    refute_nil cat_schema

    all_of = cat_schema["allOf"]
    refute_nil all_of
    assert_equal 2, all_of.length

    # First should be $ref to parent (OAS3 uses components/schemas)
    assert_equal "#/components/schemas/#{PET_SCHEMA_NAME}", all_of[0]["$ref"]
  end

  def test_oas3_dog_has_correct_child_properties
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    dog_schema = schema.dig("components", "schemas", DOG_SCHEMA_NAME)
    all_of = dog_schema["allOf"]

    child_props = all_of[1]["properties"]
    assert child_props.key?("breed")
    assert child_props.key?("pack_size")
    assert_equal "integer", child_props["pack_size"]["type"]
  end

  # === OAS 3.1 Tests ===

  def test_oas31_parent_entity_has_discriminator_object
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas31)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)
    refute_nil pet_schema

    discriminator = pet_schema["discriminator"]
    refute_nil discriminator
    assert_equal "pet_type", discriminator["propertyName"]
  end

  def test_oas31_child_entity_has_allof
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas31)

    cat_schema = schema.dig("components", "schemas", CAT_SCHEMA_NAME)
    refute_nil cat_schema

    all_of = cat_schema["allOf"]
    refute_nil all_of
    assert_equal "#/components/schemas/#{PET_SCHEMA_NAME}", all_of[0]["$ref"]
  end

  # === Cross-version consistency ===

  def test_all_versions_have_pet_properties
    %i[oas2 oas3 oas31].each do |schema_type|
      schema = GrapeOAS.generate(app: TestAPI, schema_type: schema_type)

      pet_path = schema_type == :oas2 ? ["definitions", PET_SCHEMA_NAME] : ["components", "schemas", PET_SCHEMA_NAME]
      pet_schema = schema.dig(*pet_path)

      refute_nil pet_schema, "Pet schema should exist in #{schema_type}"
      assert pet_schema["properties"].key?("pet_type"), "pet_type should exist in #{schema_type}"
      assert pet_schema["properties"].key?("name"), "name should exist in #{schema_type}"
    end
  end

  def test_all_versions_have_child_allof
    %i[oas2 oas3 oas31].each do |schema_type|
      schema = GrapeOAS.generate(app: TestAPI, schema_type: schema_type)

      cat_path = schema_type == :oas2 ? ["definitions", CAT_SCHEMA_NAME] : ["components", "schemas", CAT_SCHEMA_NAME]
      cat_schema = schema.dig(*cat_path)

      refute_nil cat_schema["allOf"], "Cat should have allOf in #{schema_type}"
      assert_equal 2, cat_schema["allOf"].length, "allOf should have 2 items in #{schema_type}"
    end
  end
end
