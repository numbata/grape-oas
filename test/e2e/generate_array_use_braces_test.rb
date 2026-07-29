# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # End-to-end coverage for the `array_use_braces` option, which appends `[]`
  # to the names of array parameters that are query-string params or
  # form/multipart body properties. JSON bodies, scalar params, and path/header
  # params are never modified.
  class GenerateArrayUseBracesTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json
      content_type :json, "application/json"
      content_type :form, "application/x-www-form-urlencoded"

      desc "List items"
      params do
        optional :ids, type: [Integer], documentation: { param_type: "query" }
        optional :name, type: String, documentation: { param_type: "query" }
      end
      get "items" do
        {}
      end

      desc "Create item"
      params do
        requires :tags, type: [String]
        requires :title, type: String
      end
      post "items" do
        {}
      end
    end

    def generate(version, **)
      GrapeOAS.generate(app: SampleAPI, schema_type: version, **)
    end

    # ---- Query parameters -------------------------------------------

    def test_oas2_array_query_param_gets_braces
      params = generate(:oas2, array_use_braces: true)["paths"]["/items"]["get"]["parameters"]

      assert(params.any? { |p| p["name"] == "ids[]" && p["in"] == "query" })
      assert(params.any? { |p| p["name"] == "name" }, "scalar query param must stay unbraced")
    end

    def test_oas3_array_query_param_gets_braces
      params = generate(:oas3, array_use_braces: true)["paths"]["/items"]["get"]["parameters"]

      assert(params.any? { |p| p["name"] == "ids[]" && p["in"] == "query" })
      assert(params.any? { |p| p["name"] == "name" })
    end

    def test_oas31_array_query_param_gets_braces
      params = generate(:oas31, array_use_braces: true)["paths"]["/items"]["get"]["parameters"]

      assert(params.any? { |p| p["name"] == "ids[]" })
    end

    def test_query_param_unchanged_when_option_off
      %i[oas2 oas3 oas31].each do |version|
        params = generate(version)["paths"]["/items"]["get"]["parameters"]

        assert(params.any? { |p| p["name"] == "ids" }, "#{version}: array query param must be bare by default")
        refute(params.any? { |p| p["name"] == "ids[]" }, "#{version}: must not add braces by default")
      end
    end

    # ---- Form-encoded body ------------------------------------------

    def test_oas3_form_body_array_property_gets_braces
      content = generate(:oas3, array_use_braces: true)
                .dig("paths", "/items", "post", "requestBody", "content")
      form_schema = content["application/x-www-form-urlencoded"]["schema"]

      assert_includes form_schema["properties"].keys, "tags[]"
      assert_includes form_schema["properties"].keys, "title"
      assert_includes form_schema["required"], "tags[]"
      assert_includes form_schema["required"], "title"
    end

    def test_oas3_json_body_is_not_braced
      content = generate(:oas3, array_use_braces: true)
                .dig("paths", "/items", "post", "requestBody", "content")

      # JSON body keeps the shared $ref; its properties live in components untouched.
      assert content["application/json"]["schema"].key?("$ref"),
             "JSON body must remain a $ref, not inlined with braces"
    end

    def test_oas2_form_body_array_property_gets_braces
      params = generate(:oas2, array_use_braces: true)["paths"]["/items"]["post"]["parameters"]
      body = params.find { |p| p["in"] == "body" }

      assert_includes body.dig("schema", "properties").keys, "tags[]"
      assert_includes body.dig("schema", "properties").keys, "title"
      assert_includes body.dig("schema", "required"), "tags[]"
    end

    def test_form_body_unchanged_when_option_off
      content = generate(:oas3)
                .dig("paths", "/items", "post", "requestBody", "content")

      assert content["application/x-www-form-urlencoded"]["schema"].key?("$ref"),
             "form body must stay a $ref (no inlining/braces) by default"
    end
  end
end
