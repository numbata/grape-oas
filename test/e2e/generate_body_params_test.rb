# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Tests that flat params mixed with nested Hash params on POST routes
  # all end up in the request body (OAS3: requestBody, OAS2: body parameter),
  # and that flat params like :name are not silently dropped when a sibling
  # Hash param causes the nested-params code path to activate.
  class GenerateBodyParamsTest < Minitest::Test
    class SampleAPI < Grape::API
      format :json

      namespace :users do
        desc "Create user"
        params do
          requires :name, type: String
          requires :address, type: Hash do
            requires :city, type: String
          end
        end
        post do
          {}
        end
      end
    end

    def test_body_group_preserves_declared_path_metadata_and_undeclared_fallback
      api = Class.new(Grape::API) do
        format :json
        params do
          with(documentation: { param_type: "body" }) do
            requires :id, type: Integer, desc: "The resource ID", documentation: { format: "int64" }
            requires :payload, type: Hash do
              requires :name, type: String
            end
          end
        end
        post(":id/:undeclared") { {} }
      end

      %i[oas2 oas3 oas31].each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/{id}/{undeclared}", "post")
        params = operation.fetch("parameters")
        id = params.find { |param| param["name"] == "id" }
        fallback = params.find { |param| param["name"] == "undeclared" }
        id_schema = version == :oas2 ? id : id.fetch("schema")
        fallback_schema = version == :oas2 ? fallback : fallback.fetch("schema")

        assert_equal "path", id["in"]
        assert id["required"]
        assert_equal "The resource ID", id["description"]
        assert_equal "integer", id_schema["type"]
        assert_equal "int64", id_schema["format"]
        assert_equal "path", fallback["in"]
        assert fallback["required"]
        assert_equal "string", fallback_schema["type"]
      end
    end

    def test_hash_path_capture_keeps_string_fallback
      api = Class.new(Grape::API) do
        params do
          requires :payload, type: Hash do
            requires :name, type: String
          end
        end
        post(":payload") { {} }
      end
      %i[oas2 oas3 oas31].each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        parameter = spec.dig("paths", "/{payload}", "post", "parameters").first
        schema = version == :oas2 ? parameter : parameter.fetch("schema")

        assert_equal "path", parameter["in"]
        assert parameter["required"]
        assert_equal "string", schema["type"]
      end
    end

    # ---- OAS3 -------------------------------------------------------

    def test_oas3_flat_string_param_appears_in_request_body
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      ref = schema.dig("paths", "/users", "post", "requestBody", "content", "application/json", "schema", "$ref")
      props = schema.dig(*ref.delete_prefix("#/").split("/"), "properties")

      assert_includes props.keys, "name", ":name must not be dropped from the OAS3 requestBody"
      assert_equal "string", props["name"]["type"]
    end

    def test_oas3_nested_hash_param_appears_in_request_body
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      ref = schema.dig("paths", "/users", "post", "requestBody", "content", "application/json", "schema", "$ref")
      props = schema.dig(*ref.delete_prefix("#/").split("/"), "properties")

      assert_includes props.keys, "address", ":address must appear in the OAS3 requestBody"
    end

    def test_oas3_nested_hash_has_child_properties
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      ref = schema.dig("paths", "/users", "post", "requestBody", "content", "application/json", "schema", "$ref")
      address = schema.dig(*ref.delete_prefix("#/").split("/"), "properties", "address")

      assert_equal "object", address["type"]
      assert_includes address["properties"].keys, "city"
      assert_equal "string", address["properties"]["city"]["type"]
    end

    def test_oas3_required_fields_include_name_and_address
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      ref = schema.dig("paths", "/users", "post", "requestBody", "content", "application/json", "schema", "$ref")
      required = schema.dig(*ref.delete_prefix("#/").split("/"), "required") || []

      assert_includes required, "name"
      assert_includes required, "address"
    end

    def test_oas3_no_spurious_query_params
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas3)
      names = (schema.dig("paths", "/users", "post", "parameters") || []).map { |p| p["name"] }

      refute_includes names, "name", ":name must not appear as a query/path param in OAS3"
      refute_includes names, "address", ":address must not appear as a query/path param in OAS3"
    end

    # ---- OAS2 -------------------------------------------------------

    def test_oas2_flat_string_param_appears_in_body
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      body_param = schema.dig("paths", "/users", "post", "parameters").find { |p| p["in"] == "body" }
      ref = body_param.dig("schema", "$ref")
      props = schema.dig(*ref.delete_prefix("#/").split("/"), "properties")

      assert_includes props.keys, "name", ":name must not be dropped from the OAS2 body parameter"
      assert_equal "string", props["name"]["type"]
    end

    def test_oas2_nested_hash_param_appears_in_body
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      body_param = schema.dig("paths", "/users", "post", "parameters").find { |p| p["in"] == "body" }
      ref = body_param.dig("schema", "$ref")
      props = schema.dig(*ref.delete_prefix("#/").split("/"), "properties")

      assert_includes props.keys, "address", ":address must appear in the OAS2 body parameter"
    end

    def test_oas2_nested_hash_has_child_properties
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      body_param = schema.dig("paths", "/users", "post", "parameters").find { |p| p["in"] == "body" }
      ref = body_param.dig("schema", "$ref")
      address = schema.dig(*ref.delete_prefix("#/").split("/"), "properties", "address")

      assert_equal "object", address["type"]
      assert_includes address["properties"].keys, "city"
      assert_equal "string", address["properties"]["city"]["type"]
    end

    def test_oas2_no_spurious_query_params
      schema = GrapeOAS.generate(app: SampleAPI, schema_type: :oas2)
      non_body = schema.dig("paths", "/users", "post", "parameters").reject { |p| p["in"] == "body" }
      names = non_body.map { |p| p["name"] }

      refute_includes names, "name", ":name must not appear as a non-body param in OAS2"
      refute_includes names, "address", ":address must not appear as a non-body param in OAS2"
    end
  end
end
