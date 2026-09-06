# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOas2AnyofExtensionTest < Minitest::Test
    class ErrorEntity < Grape::Entity
      expose :error, documentation: { type: String }
    end

    class ContactAPI < Grape::API
      format :json
      desc "Contact", success: { code: 201, one_of: [{ model: ComplexApi::UserEntity }, { model: ErrorEntity }] }
      params { requires :identifier, types: [String, Integer] }
      post("/contact") { {} }
      add_oas_documentation oas_doc_version: :oas2, oas_mount_path: "/spec", oas2_composition_extensions: true
    end

    def test_opt_in_reaches_response_and_request_schema_and_resolves_refs
      previous = GrapeOAS.schema_ref_name
      GrapeOAS.schema_ref_name = ->(name) { "Custom_#{name.split("::").last}" }
      spec = GrapeOAS.generate(app: ContactAPI, schema_type: :oas2, oas2_composition_extensions: true)
      response = spec.dig("paths", "/contact", "post", "responses", "201", "schema")

      assert_equal 2, response.fetch("x-oneOf").size
      assert spec.fetch("definitions").key?("Custom_UserEntity")
      assert spec.fetch("definitions").key?("Custom_ErrorEntity")
      request = spec.dig("definitions", "Custom_post_contact_Request", "properties", "identifier")

      assert_equal 2, request.fetch("x-oneOf").size
      assert OASValidator.validate!(spec)
      assert_refs_resolve(spec, spec)
    ensure
      GrapeOAS.schema_ref_name = previous
    end

    def test_documentation_option_enables_compatibility_extensions
      response = Rack::MockRequest.new(ContactAPI).get("/spec")

      assert_equal 200, response.status
      spec = JSON.parse(response.body)

      assert_equal 2, spec.dig("paths", "/contact", "post", "responses", "201", "schema", "x-oneOf").size
    end

    def test_default_does_not_generate_extensions
      spec = GrapeOAS.generate(app: ContactAPI, schema_type: :oas2)
      response = spec.dig("paths", "/contact", "post", "responses", "201", "schema")

      refute response.key?("x-oneOf")
      assert response.key?("$ref")
    end

    def test_oas3_uses_native_composition_without_generated_extensions
      %i[oas3 oas31].each do |dialect|
        spec = GrapeOAS.generate(app: ContactAPI, schema_type: dialect, oas2_composition_extensions: true)
        response = spec.dig("paths", "/contact", "post", "responses", "201", "content", "application/json", "schema")

        assert_equal 2, response.fetch("oneOf").size
        refute response.key?("x-oneOf")
        assert_refs_resolve(spec, spec)
      end
    end

    private

    def assert_refs_resolve(node, document)
      case node
      when Hash
        if node["$ref"]&.start_with?("#/")
          keys = node["$ref"].delete_prefix("#/").split("/")

          refute_nil document.dig(*keys), "Dangling reference: #{node["$ref"]}"
        end

        node.each_value { |child| assert_refs_resolve(child, document) }
      when Array

        node.each { |child| assert_refs_resolve(child, document) }
      end
    end
  end
end
