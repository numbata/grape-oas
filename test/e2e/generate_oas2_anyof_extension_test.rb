# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Regression: native any_of must produce x-anyOf in OAS2 so integrations
  # don't need to inject OAS2-specific extension metadata manually (issue #114).
  class GenerateOas2AnyofExtensionTest < Minitest::Test
    class ContactAPI < Grape::API
      format :json
      desc "Contact"
      get "/contact" do
        {}
      end
    end

    def contact_schema
      email = GrapeOAS::ApiModel::Schema.new(
        canonical_name: "Example::EmailContact",
        type: "object",
        properties: { "email" => GrapeOAS::ApiModel::Schema.new(type: "string") },
      )
      sms = GrapeOAS::ApiModel::Schema.new(
        canonical_name: "Example::SmsContact",
        type: "object",
        properties: { "phone" => GrapeOAS::ApiModel::Schema.new(type: "string") },
      )
      GrapeOAS::ApiModel::Schema.new(any_of: [email, sms])
    end

    def test_oas2_any_of_generates_x_any_of_with_definitions_refs
      result = GrapeOAS::Exporter::OAS2::Schema.new(contact_schema).build

      assert result.key?("x-anyOf"), "x-anyOf must be auto-generated from native any_of"
      assert_equal 2, result["x-anyOf"].length
      result["x-anyOf"].each do |entry|
        assert entry["$ref"]&.start_with?("#/definitions/"),
               "x-anyOf refs must use OAS2 #/definitions/ format, got: #{entry.inspect}"
      end
    end

    def test_oas2_any_of_keeps_first_alternative_fallback
      result = GrapeOAS::Exporter::OAS2::Schema.new(contact_schema).build

      assert result.key?("allOf"), "first-alternative allOf fallback must be present"
      assert_equal 1, result["allOf"].length
      assert result["allOf"].first["$ref"]&.start_with?("#/definitions/")
    end

    def test_oas2_any_of_with_explicit_type_still_generates_extension
      schema = contact_schema
      schema.type = "object"

      result = GrapeOAS::Exporter::OAS2::Schema.new(schema).build

      assert_equal "object", result["type"]
      assert_equal 2, result["x-anyOf"].length
      assert(result["x-anyOf"].all? { |entry| entry["$ref"]&.start_with?("#/definitions/") })
    end

    def test_oas3_any_of_uses_native_anyof_no_extension
      result = GrapeOAS::Exporter::OAS3::Schema.new(contact_schema).build

      assert result.key?("anyOf"), "OAS3 must use native anyOf"
      refute result.key?("x-anyOf"), "OAS3 must not emit x-anyOf from native any_of"
      result["anyOf"].each do |entry|
        assert entry["$ref"]&.start_with?("#/components/schemas/"),
               "anyOf refs must use OAS3 #/components/schemas/ format"
      end
    end

    def test_explicit_x_any_of_wins_over_auto_generated
      schema = contact_schema
      schema.extensions = { "x-anyOf" => [{ "$ref" => "#/definitions/Manual" }] }

      result = GrapeOAS::Exporter::OAS2::Schema.new(schema).build

      assert_equal [{ "$ref" => "#/definitions/Manual" }], result["x-anyOf"],
                   "explicitly supplied x-anyOf must override auto-generated"
    end
  end
end
