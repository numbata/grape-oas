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
  end
end
