# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Regression: explicit route consumes must be honored independently of
  # produces so a form request is not documented as consuming JSON (#117).
  class GenerateConsumesProducesTest < Minitest::Test
    class FormAPI < Grape::API
      format :json
      desc "Accept a form and return JSON",
           consumes: ["application/x-www-form-urlencoded"],
           produces: ["application/json"]
      params do
        requires :message, type: String
      end
      post("/messages") { { message: params[:message] } }
    end

    def test_oas2_uses_form_consumes_and_json_produces
      op = GrapeOAS.generate(app: FormAPI, schema_type: :oas2).dig("paths", "/messages", "post")

      assert_equal ["application/x-www-form-urlencoded"], op["consumes"]
      assert_equal ["application/json"], op["produces"]
    end

    def test_oas3_request_body_uses_form_media_type_response_stays_json
      %i[oas3 oas31].each do |dialect|
        op = GrapeOAS.generate(app: FormAPI, schema_type: dialect).dig("paths", "/messages", "post")

        assert_equal ["application/x-www-form-urlencoded"], op.dig("requestBody", "content").keys, dialect.to_s
        assert_equal ["application/json"], op.dig("responses", "201", "content").keys, dialect.to_s
      end
    end
  end
end
