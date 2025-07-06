# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOAS3Test < Minitest::Test
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

    def test_generates_openapi_v3_output
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)

      assert_kind_of Hash, schema
      assert_equal "3.0.0", schema["openapi"]

      # Confirm path and method exist
      assert_includes schema["paths"], "/books/{id}"
      assert_includes schema["paths"]["/books/{id}"], "get"

      # Confirm parameter details
      parameters = schema["paths"]["/books/{id}"]["get"]["parameters"]

      assert_equal "id", parameters.first["name"]
      assert_equal "path", parameters.first["in"]
      assert parameters.first["required"]
    end
  end
end
