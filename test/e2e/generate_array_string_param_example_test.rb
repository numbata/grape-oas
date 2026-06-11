# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateArrayStringParamExampleTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      params do
        requires :species,
                 type: [String],
                 documentation: { example: %w[dog cat] }
      end
      post "animals" do
        {}
      end
    end

    def test_oas2_preserves_full_array_example
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      property = schema.dig("definitions", "post_animals_Request", "properties", "species")

      refute_nil property
      assert_equal "array", property["type"]
      assert_equal "string", property.dig("items", "type")
      assert_equal %w[dog cat], property["example"]
    end

    def test_oas3_preserves_full_array_example
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      property = schema.dig("components", "schemas", "post_animals_Request", "properties", "species")

      refute_nil property
      assert_equal "array", property["type"]
      assert_equal "string", property.dig("items", "type")
      # Regression: was truncated to "dog" by Array(@schema.examples).first.
      assert_equal %w[dog cat], property["example"]
    end

    def test_oas31_wraps_array_example_as_single_example
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas31)
      property = schema.dig("components", "schemas", "post_animals_Request", "properties", "species")

      refute_nil property
      assert_equal "array", property["type"]
      assert_equal "string", property.dig("items", "type")
      # One array-valued example, not two scalar examples.
      assert_equal [%w[dog cat]], property["examples"]
    end
  end
end
