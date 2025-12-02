# frozen_string_literal: true

require "test_helper"

# E2E tests for Dry::Types Sum types (anyOf) - OAS 3.0+ only
class GenerateDryAnyOfTest < Minitest::Test
  # Define test types
  module Types
    include Dry.Types()

    CatType = Types::Hash.schema(
      meow_volume: Types::Integer,
      whiskers: Types::String,
    )

    DogType = Types::Hash.schema(
      bark_volume: Types::Integer,
      breed: Types::String,
    )

    AnimalType = CatType | DogType
  end

  class PetContract < Dry::Validation::Contract
    params do
      required(:name).filled(:string)
      required(:animal).filled(Types::AnimalType)
    end
  end

  class TestAPI < Grape::API
    format :json

    desc "Create a pet", contract: PetContract
    post "pets" do
      {}
    end
  end

  # Schema names include the test class prefix
  PET_SCHEMA_NAME = "GenerateDryAnyOfTest_PetContract"
  THREE_TYPE_SCHEMA_NAME = "GenerateDryAnyOfTest_ThreeTypeContract"

  # === OAS 3.0 Tests ===

  def test_oas3_generates_any_of
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)

    refute_nil pet_schema, "PetContract schema should exist in components"

    animal_prop = pet_schema.dig("properties", "animal")

    refute_nil animal_prop, "Should have animal property"

    any_of = animal_prop["anyOf"]

    refute_nil any_of, "animal should have anyOf"
    assert_equal 2, any_of.length
  end

  def test_oas3_any_of_items_have_correct_properties
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)
    any_of = pet_schema.dig("properties", "animal", "anyOf")

    # First item should be cat
    cat_props = any_of[0]["properties"]

    assert cat_props.key?("meow_volume")
    assert cat_props.key?("whiskers")

    # Second item should be dog
    dog_props = any_of[1]["properties"]

    assert dog_props.key?("bark_volume")
    assert dog_props.key?("breed")
  end

  def test_oas3_any_of_items_have_correct_types
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas3)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)
    any_of = pet_schema.dig("properties", "animal", "anyOf")

    assert_equal "integer", any_of[0]["properties"]["meow_volume"]["type"]
    assert_equal "string", any_of[0]["properties"]["whiskers"]["type"]
    assert_equal "integer", any_of[1]["properties"]["bark_volume"]["type"]
    assert_equal "string", any_of[1]["properties"]["breed"]["type"]
  end

  # === OAS 3.1 Tests ===

  def test_oas31_generates_any_of
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas31)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)

    refute_nil pet_schema

    any_of = pet_schema.dig("properties", "animal", "anyOf")

    refute_nil any_of, "animal should have anyOf in OAS 3.1"
    assert_equal 2, any_of.length
  end

  def test_oas31_any_of_has_correct_structure
    schema = GrapeOAS.generate(app: TestAPI, schema_type: :oas31)

    pet_schema = schema.dig("components", "schemas", PET_SCHEMA_NAME)
    any_of = pet_schema.dig("properties", "animal", "anyOf")

    # Both items should be objects
    any_of.each do |item|
      assert_equal "object", item["type"]
      refute_nil item["properties"]
    end
  end

  # === Three-type Sum ===

  module ThreeTypes
    include Dry.Types()

    CatType = Types::Hash.schema(meow: Types::Integer)
    DogType = Types::Hash.schema(bark: Types::Integer)
    BirdType = Types::Hash.schema(chirp: Types::Integer)
    AnimalType = CatType | DogType | BirdType
  end

  class ThreeTypeContract < Dry::Validation::Contract
    params do
      required(:animal).filled(ThreeTypes::AnimalType)
    end
  end

  class ThreeTypeAPI < Grape::API
    format :json

    desc "Create animal", contract: ThreeTypeContract
    post "animals" do
      {}
    end
  end

  def test_oas3_three_type_sum_generates_three_any_of_items
    schema = GrapeOAS.generate(app: ThreeTypeAPI, schema_type: :oas3)

    contract_schema = schema.dig("components", "schemas", THREE_TYPE_SCHEMA_NAME)

    refute_nil contract_schema, "ThreeTypeContract schema should exist"

    any_of = contract_schema.dig("properties", "animal", "anyOf")

    refute_nil any_of
    assert_equal 3, any_of.length

    all_props = any_of.flat_map { |item| item["properties"].keys }

    assert_includes all_props, "meow"
    assert_includes all_props, "bark"
    assert_includes all_props, "chirp"
  end
end
