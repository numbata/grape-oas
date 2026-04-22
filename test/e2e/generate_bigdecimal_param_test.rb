# frozen_string_literal: true

require "test_helper"
require "bigdecimal"
require "bigdecimal/util"
require "json"

module GrapeOAS
  class GenerateBigDecimalParamTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      desc "Create a forecast"
      params do
        optional :conversion_probability,
                 type: BigDecimal,
                 values: BigDecimal(0)..BigDecimal(1),
                 desc: "Predicted conversion probability",
                 documentation: { example: 0.75 }
      end
      post "forecasts" do
        {}
      end
    end

    def test_oas2_emits_numeric_min_max_for_bigdecimal_range
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      property = schema.dig("definitions", "post_forecasts_Request", "properties", "conversion_probability")

      refute_nil property
      assert_equal "number", property["type"]
      assert_equal "double", property["format"]
      assert_kind_of Numeric, property["minimum"]
      assert_kind_of Numeric, property["maximum"]
      assert_in_delta 0.0, property["minimum"]
      assert_in_delta 1.0, property["maximum"]

      round_tripped = JSON.parse(JSON.generate(schema))
      round_tripped_property = round_tripped.dig(
        "definitions", "post_forecasts_Request", "properties", "conversion_probability",
      )

      # Regression: BigDecimal#to_json previously emitted strings like "0.1e1".
      assert_kind_of Numeric, round_tripped_property["minimum"]
      assert_kind_of Numeric, round_tripped_property["maximum"]
    end

    def test_oas3_emits_numeric_min_max_for_bigdecimal_range
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      property = schema.dig("components", "schemas", "post_forecasts_Request", "properties", "conversion_probability")

      refute_nil property
      assert_equal "number", property["type"]
      assert_equal "double", property["format"]
      assert_in_delta 0.75, property["example"]
      assert_kind_of Numeric, property["minimum"]
      assert_kind_of Numeric, property["maximum"]
      assert_in_delta 0.0, property["minimum"]
      assert_in_delta 1.0, property["maximum"]

      round_tripped = JSON.parse(JSON.generate(schema))
      round_tripped_property = round_tripped.dig(
        "components", "schemas", "post_forecasts_Request", "properties", "conversion_probability",
      )

      assert_kind_of Numeric, round_tripped_property["minimum"]
      assert_kind_of Numeric, round_tripped_property["maximum"]
    end

    def test_oas31_emits_numeric_min_max_for_bigdecimal_range
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas31)
      property = schema.dig("components", "schemas", "post_forecasts_Request", "properties", "conversion_probability")

      refute_nil property
      assert_equal "number", property["type"]
      assert_kind_of Numeric, property["minimum"]
      assert_kind_of Numeric, property["maximum"]

      round_tripped = JSON.parse(JSON.generate(schema))
      round_tripped_property = round_tripped.dig(
        "components", "schemas", "post_forecasts_Request", "properties", "conversion_probability",
      )

      assert_kind_of Numeric, round_tripped_property["minimum"]
      assert_kind_of Numeric, round_tripped_property["maximum"]
    end
  end
end
