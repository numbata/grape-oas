# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateConditionalGivenTest < Minitest::Test
    class ConditionalOnlyAPI < Grape::API
      format :json
      params do
        optional :channel, type: String, values: %w[email pickup]
        given channel: ->(value) { value == "email" } do
          requires :address, type: String, allow_blank: false
        end
      end
      post("/deliveries") { {} }
    end

    class MixedRequirementAPI < Grape::API
      format :json
      params do
        requires :address, type: String
        optional :channel, type: String
        given channel: ->(value) { value == "email" } do
          requires :address, type: String
        end
      end
      post("/mixed") { {} }
    end

    def test_conditional_param_and_body_are_not_unconditionally_required
      %i[oas2 oas3 oas31].each do |dialect|
        doc = GrapeOAS.generate(app: ConditionalOnlyAPI, schema_type: dialect)
        schema = request_schema(doc, dialect, "post_deliveries_Request")

        assert schema.fetch("properties").key?("address"), "#{dialect}: address must appear in properties"
        refute_includes schema.fetch("required", []), "address", "#{dialect}: given-scoped requires must not be required"

        operation = doc.dig("paths", "/deliveries", "post")
        required = if dialect == :oas2
                     operation.fetch("parameters").find { |param| param["in"] == "body" }.fetch("required")
                   else
                     operation.dig("requestBody", "required")
                   end

        refute required, "#{dialect}: conditional fields alone must not require the request body"
      end
    end

    def test_unconditional_requirement_wins_for_same_field
      %i[oas2 oas3 oas31].each do |dialect|
        doc = GrapeOAS.generate(app: MixedRequirementAPI, schema_type: dialect)
        schema = request_schema(doc, dialect, "post_mixed_Request")

        assert_includes schema.fetch("required", []), "address", "#{dialect}: unconditional requires must win"
      end
    end

    private

    def request_schema(document, dialect, name)
      schemas = dialect == :oas2 ? document.fetch("definitions") : document.dig("components", "schemas")
      schemas.fetch(name)
    end
  end
end
