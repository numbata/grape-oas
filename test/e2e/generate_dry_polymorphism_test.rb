# frozen_string_literal: true

require "test_helper"

# E2E tests for Dry::Validation::Contract polymorphism (allOf) across OAS versions
class GenerateDryPolymorphismTest < Minitest::Test
  # Define test contracts with inheritance
  class PetContract < Dry::Validation::Contract
    params do
      required(:pet_type).filled(:string)
      required(:name).filled(:string)
    end
  end

  class CatContract < PetContract
    params do
      required(:hunting_skill).filled(:string)
    end
  end

  class DogContract < PetContract
    params do
      required(:breed).filled(:string)
      required(:pack_size).filled(:integer)
    end
  end

  class TestAPI < Grape::API
    format :json

    desc "Create a pet", contract: PetContract
    post "pets" do
      {}
    end

    desc "Create a cat", contract: CatContract
    post "cats" do
      {}
    end

    desc "Create a dog", contract: DogContract
    post "dogs" do
      {}
    end
  end

  # Schema names include the test class prefix
  PET_SCHEMA_NAME = "GenerateDryPolymorphismTest_PetContract"
  CAT_SCHEMA_NAME = "GenerateDryPolymorphismTest_CatContract"
  DOG_SCHEMA_NAME = "GenerateDryPolymorphismTest_DogContract"

  # === OAS 2.0 Tests ===

  def test_oas2_parent_contract_has_flat_schema
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas2)

    pet_schema = schema.dig("definitions", PET_SCHEMA_NAME)

    refute_nil pet_schema, "Pet schema should exist"

    # Parent should have flat properties, no allOf
    assert_nil pet_schema["allOf"]
    assert_equal "object", pet_schema["type"]
    assert pet_schema["properties"].key?("pet_type")
    assert pet_schema["properties"].key?("name")
  end

  def test_oas2_child_contract_has_allof
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
    refute child_props.key?("pet_type")
    refute child_props.key?("name")
  end

  def test_oas2_dog_contract_has_allof
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

  def test_oas3_parent_contract_has_flat_schema
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)

    refute_nil pet_schema, "Pet schema should exist"

    assert_nil pet_schema["allOf"]
    assert_equal "object", pet_schema["type"]
  end

  def test_oas3_child_contract_has_allof
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

  def test_oas31_parent_contract_has_flat_schema
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas31)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)

    refute_nil pet_schema

    assert_nil pet_schema["allOf"]
  end

  def test_oas31_child_contract_has_allof
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
