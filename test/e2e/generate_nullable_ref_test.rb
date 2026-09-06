# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Regression: OAS 3.0 nullable object refs must use a representation that
  # actually admits null, not an allOf wrapper with an ineffective
  # nullable: true (issue #118).
  class GenerateNullableRefTest < Minitest::Test
    class DetailsEntity < Grape::Entity
      expose :code, documentation: { type: String }
    end

    class ResultEntity < Grape::Entity
      expose :details, using: DetailsEntity, documentation: { nullable: true }
      expose :strict_details, using: DetailsEntity
    end

    class ResultAPI < Grape::API
      format :json
      desc "A result with optional details", success: ResultEntity
      get("/result") { {} }
    end

    def result_schemas(dialect)
      schemas = GrapeOAS.generate(app: ResultAPI, schema_type: dialect).dig("components", "schemas")
      [schemas.fetch(schemas.keys.grep(/ResultEntity/).first), schemas.fetch(schemas.keys.grep(/DetailsEntity/).first)]
    end

    def test_oas30_nullable_ref_uses_anyof_null_union
      result, details = result_schemas(:oas3)
      props = result.fetch("properties")

      details_prop = props.fetch("details")
      # An anyOf with a null-only branch actually admits null under OAS 3.0.
      assert details_prop.key?("anyOf"), "nullable ref must use anyOf null union, not an allOf wrapper"
      null_branch = details_prop["anyOf"].find { |b| b["enum"] == [nil] }

      assert null_branch, "a null-only branch (enum: [null]) must be present"
      assert_equal "object", null_branch["type"], "nullable requires an explicit type on the same OAS 3.0 schema"
      assert null_branch["nullable"], "the null branch must declare nullable: true"
      refute details_prop.key?("nullable"), "the wrapper must not carry an ineffective nullable: true"

      # The shared child entity stays non-nullable.
      refute details.key?("nullable")
      assert_equal({ "$ref" => "#/components/schemas/#{details_prop_ref_name}" }, props.fetch("strict_details"))
    end

    def test_oas31_keeps_native_null_alternative
      result, = result_schemas(:oas31)
      details_prop = result.fetch("properties").fetch("details")

      assert details_prop.key?("anyOf")
      assert(details_prop["anyOf"].any? { |b| b["type"] == "null" }, "OAS 3.1 uses type: null")
    end

    private

    def details_prop_ref_name
      GrapeOAS.generate(app: ResultAPI, schema_type: :oas3).dig("components", "schemas").keys.grep(/DetailsEntity/).first
    end
  end
end
