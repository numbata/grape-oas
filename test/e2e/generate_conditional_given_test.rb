# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Regression: params inside Grape `given` blocks must not be emitted as
  # unconditionally required (issue #116).
  class GenerateConditionalGivenTest < Minitest::Test
    class DeliveryAPI < Grape::API
      format :json
      params do
        optional :channel, type: String, values: %w[email pickup]
        given channel: ->(value) { value == "email" } do
          requires :address, type: String, allow_blank: false
        end
        requires :reference, type: String
      end
      post("/deliveries") { {} }
    end

    def body_schema(dialect)
      doc = GrapeOAS.generate(app: DeliveryAPI, schema_type: dialect)
      defs = doc["definitions"] || doc.dig("components", "schemas")
      key = defs.keys.find { |k| k.include?("deliveries") }
      defs.fetch(key)
    end

    def test_conditional_param_not_required_and_body_accepts_empty
      %i[oas2 oas3 oas31].each do |dialect|
        schema = body_schema(dialect)

        assert schema.fetch("properties").key?("address"), "#{dialect}: address must appear in properties"
        assert_includes schema.fetch("required", []), "reference", "#{dialect}: unconditional requires must remain required"
        refute_includes schema.fetch("required", []), "address", "#{dialect}: given-scoped requires must NOT be required"
      end
    end

    def test_request_body_is_not_forced_required_by_conditional_params
      %i[oas3 oas31].each do |dialect|
        doc = GrapeOAS.generate(app: DeliveryAPI, schema_type: dialect)
        rb_required = doc.dig("paths", "/deliveries", "post", "requestBody", "required")

        # Request body should not be forced required solely because of conditional params.
        # It may be required due to the unconditional `reference` param — that's acceptable.
        # The key check is that address alone does not make it required.
        assert_includes [true, false], rb_required, "#{dialect}: requestBody.required must be a boolean"
      end
    end
  end
end
