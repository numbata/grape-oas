# frozen_string_literal: true

require "test_helper"
require "fileutils"

module GrapeOAS
  class GenerateOAS2ComplexTest < Minitest::Test
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
      expose :y_position, documentation: { type: Integer }
    end

    class PageViewEventEntity < BaseEventEntity
      expose :url, documentation: { type: String }
      expose :referrer, documentation: { type: String, nullable: true }
    end

    # ============================================================
    # Dry::Schema Contracts - Various Constraint Types
    # ============================================================

    BasicContract = Dry::Schema.Params do
      required(:id).filled(:integer, gt?: 0)
      optional(:status).maybe(:string, included_in?: %w[draft active])
      optional(:tags).value(:array, min_size?: 1, max_size?: 3).each(:string)
      optional(:code).maybe(:string, format?: /\A[A-Z]{3}\d{2}\z/)
    end

    # Contract with string constraints
    StringConstraintsContract = Dry::Schema.Params do
      required(:username).filled(:string, min_size?: 3, max_size?: 20)
      required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
      optional(:bio).maybe(:string, max_size?: 500)
      optional(:website).maybe(:string)
    end

    # Contract with numeric constraints
    NumericConstraintsContract = Dry::Schema.Params do
      required(:quantity).filled(:integer, gt?: 0, lteq?: 100)
      required(:price).filled(:float, gteq?: 0.0)
      optional(:discount_percent).maybe(:float, gteq?: 0.0, lteq?: 100.0)
      optional(:priority).filled(:integer, included_in?: [1, 2, 3, 4, 5])
    end

    # Contract with arrays of different types
    ArrayTypesContract = Dry::Schema.Params do
      required(:string_tags).array(:string)
      optional(:numeric_ids).array(:integer)
      optional(:scores).array(:float)
    end

    # ============================================================
    # Dry::Validation::Contract - Inheritance (allOf in OAS3, flattened in OAS2)
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
        optional(:published).filled(:bool)
      end
    end

    class CommentContract < BaseResourceContract
      params do
        required(:body).filled(:string, min_size?: 1)
        required(:author_id).filled(:integer)
        optional(:parent_id).maybe(:integer)
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
        post { {} }

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
        post { {} }
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

      # --- Contract inheritance ---
      namespace :articles do
        desc "Create article (inherits from BaseResource)", contract: ArticleContract
        post { {} }
      end

      namespace :comments do
        desc "Create comment (inherits from BaseResource)", contract: CommentContract
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

        namespace :pageviews do
          params do
            requires :id, type: Integer
          end
          get ":id", entity: PageViewEventEntity do
            {}
          end
        end
      end

      # --- Mixed parameter locations ---
      namespace :search do
        params do
          requires :q, type: String, documentation: { param_type: "query", desc: "Search query" }
          optional :page, type: Integer, default: 1, documentation: { param_type: "query" }
          optional :per_page, type: Integer, default: 20, documentation: { param_type: "query" }
          optional :sort, type: String, values: %w[relevance date], documentation: { param_type: "query" }
        end
        get { {} }
      end

      # --- Path and header parameters ---
      namespace :tenants do
        params do
          requires :tenant_id, type: String, documentation: { param_type: "path" }
          requires "X-API-Version", type: String, documentation: { param_type: "header" }
        end
        route_param :tenant_id do
          get { {} }
        end
      end
    end

    # ============================================================
    # Test Methods
    # ============================================================

    def setup
      @schema = GrapeOAS.generate(app: API, schema_type: :oas2)
    end

    def test_generates_valid_oas2_schema
      assert_equal "2.0", @schema["swagger"]
      assert OASValidator.validate!(@schema)
      write_dump("oas2_complex.json", @schema)
    end

    # --- Entity Tests ---

    def test_entity_body_param_references_definition
      user_post = @schema["paths"]["/users"]["post"]
      payload_param = user_post["parameters"].first

      refute_nil payload_param
      assert_equal "body", payload_param["in"]
      assert_includes %w[payload body], payload_param["name"]

      ref = payload_param.dig("schema", "$ref") || payload_param.dig("schema", "properties", "payload", "$ref")

      assert_equal "#/definitions/GrapeOAS_GenerateOAS2ComplexTest_UserEntity", ref
    end

    def test_entity_response_uses_ref
      user_get_resp = @schema["paths"]["/users/{id}"]["get"]["responses"]["200"]["schema"]

      assert_equal "#/definitions/GrapeOAS_GenerateOAS2ComplexTest_UserEntity", user_get_resp["$ref"]
    end

    def test_definitions_include_all_entities
      defs = @schema["definitions"]

      %w[UserEntity ProfileEntity DetailEntity].each do |name|
        assert defs.keys.any? { |k| k.include?(name) }, "definitions should include #{name}"
      end
    end

    def test_merged_entity_fields_appear_in_parent
      defs = @schema["definitions"]
      user_def = defs[defs.keys.find { |k| k.include?("UserEntity") }]

      # Merged DetailEntity fields should appear directly in UserEntity
      assert_includes user_def["properties"].keys, "city"
      assert_includes user_def["properties"].keys, "zip"
    end

    def test_nested_entity_uses_ref
      defs = @schema["definitions"]
      user_def = defs[defs.keys.find { |k| k.include?("UserEntity") }]

      profile_prop = user_def["properties"]["profile"]

      assert_includes profile_prop["$ref"], "ProfileEntity"
    end

    def test_inherited_entity_includes_parent_fields
      defs = @schema["definitions"]
      click_def = defs[defs.keys.find { |k| k.include?("ClickEventEntity") }]

      # Should have both inherited and own fields
      assert_includes click_def["properties"].keys, "id"
      assert_includes click_def["properties"].keys, "timestamp"
      assert_includes click_def["properties"].keys, "element_id"
      assert_includes click_def["properties"].keys, "x_position"
    end

    # --- Basic Contract Tests ---

    def test_basic_contract_properties
      contract_param = @schema["paths"]["/contracts"]["post"]["parameters"].first
      props = contract_param["schema"]["properties"]

      assert_equal %w[code id status tags].sort, props.keys.sort
    end

    def test_basic_contract_enum_constraint
      contract_param = @schema["paths"]["/contracts"]["post"]["parameters"].first
      props = contract_param["schema"]["properties"]

      assert_equal %w[draft active], props["status"]["enum"]
    end

    def test_basic_contract_array_constraints
      contract_param = @schema["paths"]["/contracts"]["post"]["parameters"].first
      props = contract_param["schema"]["properties"]

      assert_equal 1, props["tags"]["minItems"]
      assert_equal 3, props["tags"]["maxItems"]
    end

    def test_basic_contract_pattern_constraint
      contract_param = @schema["paths"]["/contracts"]["post"]["parameters"].first
      props = contract_param["schema"]["properties"]

      assert_equal "\\A[A-Z]{3}\\d{2}\\z", props["code"]["pattern"]
    end

    def test_basic_contract_numeric_constraint
      contract_param = @schema["paths"]["/contracts"]["post"]["parameters"].first
      props = contract_param["schema"]["properties"]

      assert_equal 0, props["id"]["minimum"]
      assert props["id"]["exclusiveMinimum"]
    end

    # --- String Constraints Contract Tests ---

    def test_string_min_max_length_constraints
      param = @schema["paths"]["/registrations"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal 3, props["username"]["minLength"]
      assert_equal 20, props["username"]["maxLength"]
      assert_equal 500, props["bio"]["maxLength"]
    end

    def test_string_format_constraint
      param = @schema["paths"]["/registrations"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      refute_nil props["email"]["pattern"]
    end

    # --- Numeric Constraints Contract Tests ---

    def test_numeric_greater_than_constraint
      param = @schema["paths"]["/orders"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal 0, props["quantity"]["minimum"]
      assert props["quantity"]["exclusiveMinimum"]
    end

    def test_numeric_less_than_or_equal_constraint
      param = @schema["paths"]["/orders"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal 100, props["quantity"]["maximum"]
      refute props["quantity"]["exclusiveMaximum"]
    end

    def test_numeric_greater_than_or_equal_constraint
      param = @schema["paths"]["/orders"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_in_delta(0.0, props["price"]["minimum"])
      refute props["price"]["exclusiveMinimum"]
    end

    def test_optional_numeric_field_exists
      param = @schema["paths"]["/orders"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      # discount_percent is optional (maybe(:float))
      # Note: maybe() types currently resolve to string - this is a known limitation
      assert_includes props.keys, "discount_percent"
    end

    def test_numeric_enum_constraint
      param = @schema["paths"]["/orders"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal [1, 2, 3, 4, 5], props["priority"]["enum"]
    end

    # --- Array Types Contract Tests ---

    def test_array_of_strings
      param = @schema["paths"]["/bulk"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal "array", props["string_tags"]["type"]
      assert_equal "string", props["string_tags"]["items"]["type"]
    end

    def test_array_of_integers
      param = @schema["paths"]["/bulk"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal "array", props["numeric_ids"]["type"]
      assert_equal "integer", props["numeric_ids"]["items"]["type"]
    end

    def test_array_of_floats
      param = @schema["paths"]["/bulk"]["post"]["parameters"].first
      props = param["schema"]["properties"]

      assert_equal "array", props["scores"]["type"]
      assert_equal "number", props["scores"]["items"]["type"]
    end

    # --- Contract Inheritance Tests (OAS2 uses allOf with $ref) ---

    def test_inherited_contract_uses_ref
      param = @schema["paths"]["/articles"]["post"]["parameters"].first

      # Body param should reference the ArticleContract definition
      assert_includes param["schema"]["$ref"], "ArticleContract"
    end

    def test_inherited_contract_definition_uses_allof
      defs = @schema["definitions"]
      article_def = defs[defs.keys.find { |k| k.include?("ArticleContract") }]

      # Should use allOf composition
      refute_nil article_def["allOf"], "ArticleContract should use allOf"
      assert_equal 2, article_def["allOf"].length

      # First element should be $ref to parent
      assert_includes article_def["allOf"][0]["$ref"], "BaseResourceContract"

      # Second element should be child-specific properties
      child_props = article_def["allOf"][1]["properties"]

      assert_includes child_props.keys, "title"
      assert_includes child_props.keys, "content"
    end

    def test_parent_contract_definition_has_base_fields
      defs = @schema["definitions"]
      base_def = defs[defs.keys.find { |k| k.include?("BaseResourceContract") }]

      assert_includes base_def["properties"].keys, "id"
      assert_includes base_def["properties"].keys, "created_at"
      assert_includes base_def["properties"].keys, "updated_at"
    end

    def test_sibling_contracts_share_parent_ref
      defs = @schema["definitions"]

      article_def = defs[defs.keys.find { |k| k.include?("ArticleContract") }]
      comment_def = defs[defs.keys.find { |k| k.include?("CommentContract") }]

      # Both should reference the same parent
      article_parent_ref = article_def["allOf"][0]["$ref"]
      comment_parent_ref = comment_def["allOf"][0]["$ref"]

      assert_equal article_parent_ref, comment_parent_ref
      assert_includes article_parent_ref, "BaseResourceContract"
    end

    # --- Parameter Location Tests ---

    def test_query_parameter_location
      search_params = @schema["paths"]["/search"]["get"]["parameters"]

      q_param = search_params.find { |p| p["name"] == "q" }

      assert_equal "query", q_param["in"]
      assert q_param["required"]
    end

    def test_optional_query_parameter
      search_params = @schema["paths"]["/search"]["get"]["parameters"]

      page_param = search_params.find { |p| p["name"] == "page" }

      assert_equal "query", page_param["in"]
      refute page_param["required"]
    end

    def test_path_parameter
      tenant_params = @schema["paths"]["/tenants/{tenant_id}"]["get"]["parameters"]

      tenant_param = tenant_params.find { |p| p["name"] == "tenant_id" }

      assert_equal "path", tenant_param["in"]
      assert tenant_param["required"]
    end

    def test_header_parameter
      tenant_params = @schema["paths"]["/tenants/{tenant_id}"]["get"]["parameters"]

      version_param = tenant_params.find { |p| p["name"] == "X-API-Version" }

      assert_equal "header", version_param["in"]
    end

    # --- nullable_strategy: Constants::NullableStrategy::EXTENSION tests ---

    def test_nullable_strategy_extension_emits_x_nullable_on_entity_fields
      schema = GrapeOAS.generate(app: API, schema_type: :oas2, nullable_strategy: Constants::NullableStrategy::EXTENSION)
      defs = schema["definitions"]

      detail_def = defs[defs.keys.find { |k| k.include?("DetailEntity") }]
      zip_prop = detail_def["properties"]["zip"]

      assert zip_prop["x-nullable"], "nullable entity field should have x-nullable"
      refute detail_def["properties"]["city"].key?("x-nullable"), "non-nullable field should not have x-nullable"
    end

    def test_nullable_strategy_extension_emits_x_nullable_on_ref_properties
      schema = GrapeOAS.generate(app: API, schema_type: :oas2, nullable_strategy: Constants::NullableStrategy::EXTENSION)
      defs = schema["definitions"]

      profile_def = defs[defs.keys.find { |k| k.include?("ProfileEntity") }]
      bio_prop = profile_def["properties"]["bio"]

      assert bio_prop["x-nullable"], "nullable string field should have x-nullable"
    end

    def test_nullable_strategy_extension_emits_x_nullable_on_contract_fields
      schema = GrapeOAS.generate(app: API, schema_type: :oas2, nullable_strategy: Constants::NullableStrategy::EXTENSION)

      param = schema["paths"]["/contracts"]["post"]["parameters"].first
      status_prop = param["schema"]["properties"]["status"]

      assert status_prop["x-nullable"], "nullable contract field should have x-nullable"
    end

    def test_default_oas2_does_not_emit_x_nullable
      # Without nullable_strategy, nullable fields should not have x-nullable
      defs = @schema["definitions"]
      detail_def = defs[defs.keys.find { |k| k.include?("DetailEntity") }]
      zip_prop = detail_def["properties"]["zip"]

      refute zip_prop.key?("x-nullable"), "default OAS2 should not emit x-nullable"
    end

    # --- backward compatibility: nullable_keyword option ---

    def test_legacy_nullable_keyword_false_maps_to_type_array
      schema = GrapeOAS.generate(app: API, schema_type: :oas3, nullable_keyword: false)
      defs = schema.dig("components", "schemas")

      detail_def = defs[defs.keys.find { |k| k.include?("DetailEntity") }]
      zip_prop = detail_def["properties"]["zip"]

      assert_equal %w[string null], zip_prop["type"], "nullable_keyword: false should produce type array"
      refute zip_prop.key?("nullable")
    end

    def test_legacy_nullable_keyword_true_maps_to_keyword
      schema = GrapeOAS.generate(app: API, schema_type: :oas3, nullable_keyword: true)
      defs = schema.dig("components", "schemas")

      detail_def = defs[defs.keys.find { |k| k.include?("DetailEntity") }]
      zip_prop = detail_def["properties"]["zip"]

      assert_equal "string", zip_prop["type"], "nullable_keyword: true should keep scalar type"
      assert zip_prop["nullable"]
    end

    def test_nullable_strategy_takes_precedence_over_legacy_nullable_keyword
      schema = GrapeOAS.generate(
        app: API, schema_type: :oas3,
        nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
        nullable_keyword: true,
      )
      defs = schema.dig("components", "schemas")

      detail_def = defs[defs.keys.find { |k| k.include?("DetailEntity") }]
      zip_prop = detail_def["properties"]["zip"]

      assert_equal %w[string null], zip_prop["type"], "nullable_strategy should override nullable_keyword"
    end

    # ============================================================
    # Helper Methods
    # ============================================================

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
