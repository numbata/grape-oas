# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOAS2Test < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      namespace :books do
        desc "Get a book"
        params do
          requires :id, type: Integer, desc: "Book ID"
        end
        get ":id" do
          { id: params[:id], title: "GOS" }
        end
      end
    end

    def test_generates_openapi_v2_output
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)

      assert_equal "2.0", schema["swagger"]

      # Confirm path and method exist
      assert_includes schema["paths"], "/books/{id}"
      assert_includes schema["paths"]["/books/{id}"], "get"

      # Confirm parameter details
      parameters = schema["paths"]["/books/{id}"]["get"]["parameters"]

      assert_equal "id", parameters.first["name"]
      assert_equal "path", parameters.first["in"]
      assert parameters.first["required"]
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

    def test_oas2_emits_x_nullable_for_entity_exposure_with_documentation_x_nullable
      schema = GrapeOAS.generate(app: XNullableEntityAPI, schema_type: :oas2)
      defs = schema["definitions"]
      entity_def = defs[defs.keys.find { |k| k.include?("XNullableEntity") }]
      note_prop = entity_def["properties"]["note"]

      assert_equal "string", note_prop["type"]
      assert note_prop["x-nullable"], "OAS 2.0 default (EXTENSION) should emit x-nullable for x: { nullable: true } on entity"
    end
  end
end
