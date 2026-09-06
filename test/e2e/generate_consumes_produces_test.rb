# frozen_string_literal: true

require "test_helper"

module GrapeOAS
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

    def test_form_request_succeeds_at_runtime
      response = Rack::MockRequest.new(FormAPI).post(
        "/messages", "CONTENT_TYPE" => "application/x-www-form-urlencoded", input: "message=hello",
      )

      assert_equal 201, response.status
      assert_equal({ "message" => "hello" }, JSON.parse(response.body))
    end

    def test_oas2_uses_form_consumes_and_json_produces
      spec = GrapeOAS.generate(app: FormAPI, schema_type: :oas2)

      assert OASValidator.validate!(spec)
      op = spec.dig("paths", "/messages", "post")

      assert_equal ["application/x-www-form-urlencoded"], op["consumes"]
      assert_equal ["application/json"], op["produces"]
      assert_equal(
        [{ "name" => "message", "in" => "formData", "required" => true, "type" => "string" }],
        op["parameters"],
      )
    end

    def test_oas3_request_body_uses_form_media_type_response_stays_json
      %i[oas3 oas31].each do |dialect|
        spec = GrapeOAS.generate(app: FormAPI, schema_type: dialect)

        assert OASValidator.validate!(spec)
        op = spec.dig("paths", "/messages", "post")

        assert_equal ["application/x-www-form-urlencoded"], op.dig("requestBody", "content").keys, dialect.to_s
        assert_equal ["application/json"], op.dig("responses", "201", "content").keys, dialect.to_s
      end
    end
  end
end
