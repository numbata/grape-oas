# frozen_string_literal: true

require "test_helper"
require "fileutils"

module GrapeOAS
  class GenerateOAS3ComplexTest < Minitest::Test
    require_relative "../support/oas_validator"

    # ============================================================
    # Grape Entity Definitions - Nested, Merged, and Inherited
    # ============================================================

    class DetailEntity < Grape::Entity
      expose :city, documentation: { type: String }
      expose :zip, documentation: { type: String, nullable: true }
    end

    class ProfileEntity < Grape::Entity
      expose :bio, documentation: { type: String, nullable: true }
      expose :address, using: DetailEntity, documentation: { type: DetailEntity }
    end

    class UserEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :name, documentation: { type: String }
      expose :profile, using: ProfileEntity, documentation: { type: ProfileEntity }
      expose :tags, documentation: { type: String, is_array: true }
      expose :extras, using: DetailEntity, merge: true
    end

    # Entity inheritance example
    class BaseEventEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :timestamp, documentation: { type: DateTime }
    end

    class ClickEventEntity < BaseEventEntity
      expose :element_id, documentation: { type: String }
      expose :x_position, documentation: { type: Integer }
    end

    # ============================================================
    # Dry::Schema Contracts - Various Constraint Types
    # ============================================================

    BasicContract = Dry::Schema.Params do
      required(:id).filled(:integer, gt?: 0)
      optional(:status).maybe(:string, included_in?: %w[draft active])
      optional(:tags).array(:string, min_size?: 1, max_size?: 3)
      optional(:code).maybe(:string, format?: /\A[A-Z]{3}\d{2}\z/)
    end

    # Contract with string constraints
    StringConstraintsContract = Dry::Schema.Params do
      required(:username).filled(:string, min_size?: 3, max_size?: 20)
      required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
      optional(:bio).maybe(:string, max_size?: 500)
    end

    # Contract with numeric constraints
    NumericConstraintsContract = Dry::Schema.Params do
      required(:quantity).filled(:integer, gt?: 0, lteq?: 100)
      required(:price).filled(:float, gteq?: 0.0)
      optional(:priority).filled(:integer, included_in?: [1, 2, 3, 4, 5])
    end

    # Contract with arrays of different types
    ArrayTypesContract = Dry::Schema.Params do
      required(:string_tags).array(:string)
      optional(:numeric_ids).array(:integer)
      optional(:scores).array(:float)
    end

    # ============================================================
    # Dry::Validation::Contract - Inheritance (allOf)
    # ============================================================

    class BaseResourceContract < Dry::Validation::Contract
      params do
        required(:id).filled(:integer)
        required(:created_at).filled(:string)
        optional(:updated_at).maybe(:string)
      end
    end

    class ArticleContract < BaseResourceContract
      params do
        required(:title).filled(:string, min_size?: 1, max_size?: 200)
        required(:content).filled(:string)
        optional(:tags).array(:string)
      end
    end

    class CommentContract < BaseResourceContract
      params do
        required(:body).filled(:string, min_size?: 1)
        required(:author_id).filled(:integer)
      end
    end

    # ============================================================
    # Dry::Types Sum Types (anyOf) - OAS3+ only
    # ============================================================

    module Types
      include Dry.Types()

      # Simple two-type sum
      CatType = Types::Hash.schema(
        meow_volume: Types::Integer,
        whiskers: Types::String,
      )

      DogType = Types::Hash.schema(
        bark_volume: Types::Integer,
        breed: Types::String,
      )

      PetType = CatType | DogType

      # Three-type sum
      CircleShape = Types::Hash.schema(
        radius: Types::Float,
      )

      RectangleShape = Types::Hash.schema(
        width: Types::Float,
        height: Types::Float,
      )

      TriangleShape = Types::Hash.schema(
        base: Types::Float,
        height: Types::Float,
      )

      ShapeType = CircleShape | RectangleShape | TriangleShape
    end

    class PetContract < Dry::Validation::Contract
      params do
        required(:name).filled(:string)
        required(:pet).filled(Types::PetType)
      end
    end

    class DrawingContract < Dry::Validation::Contract
      params do
        required(:title).filled(:string)
        required(:shapes).array(Types::ShapeType)
      end
    end

    # ============================================================
    # API Definition
    # ============================================================

    class API < Grape::API
      format :json

      # --- User endpoints with Entity ---
      namespace :users do
        params do
          requires :payload, type: UserEntity, documentation: { param_type: "body" }
        end
        post do
          {}
        end

        params do
          requires :id, type: Integer
        end
        get ":id", entity: UserEntity do
          {}
        end
      end

      # --- Basic contract endpoint ---
      namespace :contracts do
        desc "Basic contract endpoint", contract: BasicContract
        post do
          {}
        end
      end

      # --- String constraints ---
      namespace :registrations do
        desc "User registration with string validations", contract: StringConstraintsContract
        post { {} }
      end

      # --- Numeric constraints ---
      namespace :orders do
        desc "Create order with numeric constraints", contract: NumericConstraintsContract
        post { {} }
      end

      # --- Array types ---
      namespace :bulk do
        desc "Bulk operation with various array types", contract: ArrayTypesContract
        post { {} }
      end

      # --- Contract inheritance (allOf) ---
      namespace :articles do
        desc "Create article (inherits from BaseResource)", contract: ArticleContract
        post { {} }
      end

      namespace :comments do
        desc "Create comment (inherits from BaseResource)", contract: CommentContract
        post { {} }
      end

      # --- Sum types (anyOf) - OAS3+ only ---
      namespace :pets do
        desc "Create pet with sum type", contract: PetContract
        post { {} }
      end

      namespace :drawings do
        desc "Create drawing with array of sum types", contract: DrawingContract
        post { {} }
      end

      # --- Entity inheritance ---
      namespace :events do
        namespace :clicks do
          params do
            requires :id, type: Integer
          end
          get ":id", entity: ClickEventEntity do
            {}
          end
        end
      end
    end

    # ============================================================
    # Test Methods
    # ============================================================

    def setup
      @schema = GrapeOAS.generate(app: API, schema_type: :oas3)
    end

    def test_generates_valid_oas3_schema
      # OAS3 version may vary based on exporter configuration
      assert @schema["openapi"].start_with?("3.0")
      assert OASValidator.validate!(@schema)
      write_dump("oas3_complex.json", @schema)
    end

    def test_oas31_generates_valid_schema
      schema = GrapeOAS.generate(app: API, schema_type: :oas31)

      assert_equal "3.1.0", schema["openapi"]
      assert OASValidator.validate!(schema)
      write_dump("oas31_complex.json", schema)
    end

    # --- Entity Tests ---

    def test_components_include_all_entities
      components = @schema.dig("components", "schemas")

      refute_nil components

      %w[UserEntity ProfileEntity DetailEntity].each do |name|
        assert components.keys.any? { |k| k.include?(name) }, "components should include #{name}"
      end
    end

    def test_entity_request_body_uses_ref
      user_post = @schema["paths"]["/users"]["post"]
      req_schema = user_post["requestBody"]["content"]["application/json"]["schema"]
      payload = req_schema["properties"]["payload"]

      assert_includes payload["$ref"], "UserEntity"
    end

    def test_entity_response_uses_ref
      user_get_resp = @schema["paths"]["/users/{id}"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]

      assert_includes user_get_resp["$ref"], "UserEntity"
    end

    def test_merged_entity_fields_in_parent
      components = @schema.dig("components", "schemas")
      user_component = components[components.keys.find { |k| k.include?("UserEntity") }]

      assert_includes user_component["properties"].keys, "city"
      assert_includes user_component["properties"].keys, "zip"
    end

    def test_nested_entity_has_properties
      components = @schema.dig("components", "schemas")
      detail_component = components[components.keys.find { |k| k.include?("DetailEntity") }]

      assert detail_component["properties"].key?("city")
      assert detail_component["properties"].key?("zip")
    end

    def test_inherited_entity_includes_parent_fields
      components = @schema.dig("components", "schemas")
      click_def = components[components.keys.find { |k| k.include?("ClickEventEntity") }]

      # Should have both inherited and own fields
      assert_includes click_def["properties"].keys, "id"
      assert_includes click_def["properties"].keys, "timestamp"
      assert_includes click_def["properties"].keys, "element_id"
    end

    # --- Basic Contract Tests ---

    def test_basic_contract_properties
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal %w[code id status tags].sort, contract_body["properties"].keys.sort
    end

    def test_basic_contract_enum_constraint
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal %w[draft active], contract_body["properties"]["status"]["enum"]
    end

    def test_basic_contract_array_constraints
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal 1, contract_body["properties"]["tags"]["minItems"]
      assert_equal 3, contract_body["properties"]["tags"]["maxItems"]
    end

    def test_basic_contract_pattern_constraint
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal "\\A[A-Z]{3}\\d{2}\\z", contract_body["properties"]["code"]["pattern"]
    end

    def test_basic_contract_numeric_constraint
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal 0, contract_body["properties"]["id"]["minimum"]
      assert contract_body["properties"]["id"]["exclusiveMinimum"]
    end

    def test_basic_contract_required_fields
      contract_body = @schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_includes contract_body["required"], "id"
      refute_includes contract_body["required"], "status"
    end

    # --- String Constraints Tests ---

    def test_string_min_max_length
      body = request_body_schema("/registrations")

      assert_equal 3, body["properties"]["username"]["minLength"]
      assert_equal 20, body["properties"]["username"]["maxLength"]
      assert_equal 500, body["properties"]["bio"]["maxLength"]
    end

    def test_string_pattern_constraint
      body = request_body_schema("/registrations")

      refute_nil body["properties"]["email"]["pattern"]
    end

    # --- Numeric Constraints Tests ---

    def test_numeric_greater_than
      body = request_body_schema("/orders")

      assert_equal 0, body["properties"]["quantity"]["minimum"]
      assert body["properties"]["quantity"]["exclusiveMinimum"]
    end

    def test_numeric_less_than_or_equal
      body = request_body_schema("/orders")

      assert_equal 100, body["properties"]["quantity"]["maximum"]
      refute body["properties"]["quantity"]["exclusiveMaximum"]
    end

    def test_numeric_enum_values
      body = request_body_schema("/orders")

      assert_equal [1, 2, 3, 4, 5], body["properties"]["priority"]["enum"]
    end

    # --- Array Types Tests ---

    def test_array_of_strings
      body = request_body_schema("/bulk")

      assert_equal "array", body["properties"]["string_tags"]["type"]
      assert_equal "string", body["properties"]["string_tags"]["items"]["type"]
    end

    def test_array_of_integers
      body = request_body_schema("/bulk")

      assert_equal "array", body["properties"]["numeric_ids"]["type"]
      assert_equal "integer", body["properties"]["numeric_ids"]["items"]["type"]
    end

    def test_array_of_floats
      body = request_body_schema("/bulk")

      assert_equal "array", body["properties"]["scores"]["type"]
      assert_equal "number", body["properties"]["scores"]["items"]["type"]
    end

    # --- Contract Inheritance (allOf) Tests ---

    def test_inherited_contract_uses_ref
      body = request_body_schema("/articles")

      # Should reference the ArticleContract in components
      assert_includes body["$ref"], "ArticleContract"
    end

    def test_inherited_contract_definition_uses_allof
      components = @schema.dig("components", "schemas")
      article_def = components[components.keys.find { |k| k.include?("ArticleContract") }]

      refute_nil article_def["allOf"], "ArticleContract should use allOf"
      assert_equal 2, article_def["allOf"].length
    end

    def test_inherited_contract_refs_parent
      components = @schema.dig("components", "schemas")
      article_def = components[components.keys.find { |k| k.include?("ArticleContract") }]

      # First element should be $ref to parent
      assert_includes article_def["allOf"][0]["$ref"], "BaseResourceContract"
    end

    def test_inherited_contract_has_child_properties
      components = @schema.dig("components", "schemas")
      article_def = components[components.keys.find { |k| k.include?("ArticleContract") }]

      child_props = article_def["allOf"][1]["properties"]

      assert_includes child_props.keys, "title"
      assert_includes child_props.keys, "content"
    end

    def test_parent_contract_has_base_fields
      components = @schema.dig("components", "schemas")
      base_def = components[components.keys.find { |k| k.include?("BaseResourceContract") }]

      assert_includes base_def["properties"].keys, "id"
      assert_includes base_def["properties"].keys, "created_at"
    end

    def test_sibling_contracts_share_parent
      components = @schema.dig("components", "schemas")

      article_def = components[components.keys.find { |k| k.include?("ArticleContract") }]
      comment_def = components[components.keys.find { |k| k.include?("CommentContract") }]

      article_parent_ref = article_def["allOf"][0]["$ref"]
      comment_parent_ref = comment_def["allOf"][0]["$ref"]

      assert_equal article_parent_ref, comment_parent_ref
    end

    # --- Sum Types (anyOf) Tests ---

    def test_sum_type_generates_anyof
      pet_schema = component_schema("PetContract")
      pet_prop = pet_schema["properties"]["pet"]

      refute_nil pet_prop["anyOf"], "pet should have anyOf"
      assert_equal 2, pet_prop["anyOf"].length
    end

    def test_sum_type_anyof_items_have_correct_properties
      pet_schema = component_schema("PetContract")
      any_of = pet_schema["properties"]["pet"]["anyOf"]

      # First item should be cat
      cat_props = any_of[0]["properties"]

      assert cat_props.key?("meow_volume")
      assert cat_props.key?("whiskers")

      # Second item should be dog
      dog_props = any_of[1]["properties"]

      assert dog_props.key?("bark_volume")
      assert dog_props.key?("breed")
    end

    def test_three_type_sum_generates_three_anyof_items
      drawing_schema = component_schema("DrawingContract")
      shapes_prop = drawing_schema["properties"]["shapes"]

      # shapes is an array of sum types
      assert_equal "array", shapes_prop["type"]

      items_any_of = shapes_prop["items"]["anyOf"]

      refute_nil items_any_of
      assert_equal 3, items_any_of.length
    end

    def test_three_type_sum_has_all_shape_properties
      drawing_schema = component_schema("DrawingContract")
      items_any_of = drawing_schema["properties"]["shapes"]["items"]["anyOf"]

      all_props = items_any_of.flat_map { |item| item["properties"].keys }

      assert_includes all_props, "radius"      # Circle
      assert_includes all_props, "width"       # Rectangle
      assert_includes all_props, "base"        # Triangle
    end

    # ============================================================
    # Helper Methods
    # ============================================================

    def request_body_schema(path)
      @schema["paths"][path]["post"]["requestBody"]["content"]["application/json"]["schema"]
    end

    def component_schema(name)
      components = @schema.dig("components", "schemas")
      components[components.keys.find { |k| k.include?(name) }]
    end

    def write_dump(filename, payload)
      return unless ENV["WRITE_OAS_SNAPSHOTS"]

      dir = File.join(Dir.pwd, "tmp", "oas_dumps")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, filename)
      File.write(path, JSON.pretty_generate(payload))
      warn "wrote #{path}"
    end
  end
end
