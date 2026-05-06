# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOAS31Test < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      namespace :books do
        desc "Get a book"
        params do
          optional :id, type: Integer, desc: "Book ID"
        end
        get do
          { title: "GOS" }
        end
      end
    end

    def test_generates_openapi_v31_output
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas31)

      assert_kind_of Hash, schema
      assert_equal "3.1.0", schema["openapi"]
      refute schema.key?("$schema"), "OAS3.1 should omit $schema per spec"
      assert_includes schema["paths"], "/books"
      get_op = schema["paths"]["/books"]["get"]

      assert get_op
      params = get_op["parameters"]

      assert_equal "query", params.first["in"]
    end

    class XNullableEntity < Grape::Entity
      expose :note, documentation: { type: String, x: { nullable: true } }
    end

    class XNullableEntityAPI < Grape::API
      format :json

      namespace :notes do
        get entity: XNullableEntity do
          {}
        end
      end
    end

    def test_oas31_emits_type_array_for_entity_exposure_with_documentation_x_nullable
      schema = GrapeOAS.generate(app: XNullableEntityAPI, schema_type: :oas31)
      components = schema.dig("components", "schemas")
      entity_def = components[components.keys.find { |k| k.include?("XNullableEntity") }]
      note_prop = entity_def["properties"]["note"]

      assert_equal %w[string null], note_prop["type"], "OAS 3.1 should use type array for x: { nullable: true } on entity"
      refute note_prop.key?("nullable"), "OAS 3.1 must not emit nullable keyword"
    end
  end
end
