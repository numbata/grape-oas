# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3CompositionExtensionsTest < Minitest::Test
      def setup
        @email = ApiModel::Schema.new(canonical_name: "EmailContact", type: "object")
        @sms = ApiModel::Schema.new(canonical_name: "SmsContact", type: "object")
      end

      def test_oas3_drops_oas2_x_any_of_when_native_any_of_exists
        schema = ApiModel::Schema.new(
          any_of: [@email, @sms],
          extensions: {
            "x-anyOf" => [
              { "$ref" => "#/definitions/EmailContact" },
              { "$ref" => "#/definitions/SmsContact" }
            ],
            "x-label" => "contact"
          },
        )

        [OAS3::Schema, OAS31::Schema].each do |exporter|
          result = exporter.new(schema).build

          assert_equal(
            [
              { "$ref" => "#/components/schemas/EmailContact" },
              { "$ref" => "#/components/schemas/SmsContact" }
            ],
            result["anyOf"],
          )
          refute result.key?("x-anyOf")
          assert_equal "contact", result["x-label"]
        end
      end

      def test_oas3_drops_only_extension_matching_native_composition
        schema = ApiModel::Schema.new(
          one_of: [@email, @sms],
          extensions: { "x-oneOf" => [], "x-anyOf" => [{ "type" => "string" }] },
        )

        result = OAS3::Schema.new(schema).build

        refute result.key?("x-oneOf")
        assert_equal [{ "type" => "string" }], result["x-anyOf"]
      end
    end
  end
end
