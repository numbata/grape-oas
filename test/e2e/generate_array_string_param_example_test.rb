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

    class IntegerArrayAPI < Grape::API
      format :json

      params do
        requires :ages,
                 type: [Integer],
                 documentation: { example: [1, 2] }
      end
      post "people" do
        {}
      end
    end

    def test_oas3_preserves_integer_array_example
      schema = GrapeOAS.generate(app: IntegerArrayAPI, schema_type: :oas3)
      property = schema.dig("components", "schemas", "post_people_Request", "properties", "ages")

      assert_equal "array", property["type"]
      assert_equal "integer", property.dig("items", "type")
      # Elements stay integers, and the array is not truncated.
      assert_equal [1, 2], property["example"]
    end

    def test_oas31_wraps_integer_array_example
      schema = GrapeOAS.generate(app: IntegerArrayAPI, schema_type: :oas31)
      property = schema.dig("components", "schemas", "post_people_Request", "properties", "ages")

      assert_equal "array", property["type"]
      assert_equal "integer", property.dig("items", "type")
      assert_equal [[1, 2]], property["examples"]
    end

    # Regression: an array example on a *scalar*-typed schema must not crash the
    # exporter (coerce_example previously called Array#to_i). The input is
    # malformed, but generation must succeed rather than raise.
    class ScalarWithArrayExampleEntity < Grape::Entity
      expose :status, documentation: { type: Integer, example: [1, 2] }
    end

    class ScalarExampleAPI < Grape::API
      format :json

      desc "list", entity: ScalarWithArrayExampleEntity
      get "statuses" do
        present({}, with: ScalarWithArrayExampleEntity)
      end
    end

    def test_array_example_on_scalar_type_does_not_crash
      %i[oas2 oas3 oas31].each do |version|
        schema = GrapeOAS.generate(app: ScalarExampleAPI, schema_type: version)
        schemas = schema["definitions"] || schema.dig("components", "schemas")
        _key, entity_schema = schemas.find { |name, _| name.end_with?("ScalarWithArrayExampleEntity") }
        property = entity_schema.dig("properties", "status")

        assert_equal "integer", property["type"], "unexpected shape for #{version}"
      end
    end
  end
end
