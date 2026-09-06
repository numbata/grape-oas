# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3NullableRootRefTest < Minitest::Test
      def test_nullable_root_request_and_response_refs_admit_null
        [[OAS3::Schema, "3.0.3", Constants::NullableStrategy::KEYWORD],
         [OAS31::Schema, "3.1.0", Constants::NullableStrategy::TYPE_ARRAY]].each do |builder, version, strategy|
          nullable = named_details(nullable: true, description: "Optional payload")
          strict = named_details(nullable: false)

          request = OAS3::RequestBody.new(
            ApiModel::RequestBody.new(media_types: [media(nullable)]),
            nil,
            nullable_strategy: strategy,
            schema_builder: builder,
          ).build
          responses = OAS3::Response.new(
            [
              ApiModel::Response.new(http_status: "200", description: "Optional", media_types: [media(nullable)]),
              ApiModel::Response.new(http_status: "201", description: "Required", media_types: [media(strict)])
            ],
            nil,
            nullable_strategy: strategy,
            schema_builder: builder,
          ).build

          nullable_schema = request.dig("content", "application/json", "schema")

          assert_equal nullable_schema, responses.dig("200", "content", "application/json", "schema")
          assert_equal "Optional payload", nullable_schema["description"]
          assert nullable_schema.key?("anyOf"), "#{version}: root nullable ref must use null union"
          assert_equal({ "$ref" => "#/components/schemas/Details" }, nullable_schema["anyOf"].first,
                       "#{version}: non-null alternative should be a bare $ref",)
          refute nullable_schema["anyOf"].first.key?("allOf")

          strict_schema = responses.dig("201", "content", "application/json", "schema")

          assert_equal({ "$ref" => "#/components/schemas/Details" }, strict_schema)

          doc = document(request_body: request, responses: responses, version: version)

          assert OASValidator.validate!(doc)

          optional = JSONSchemer.openapi(doc)

          assert optional.ref("#/paths/~1items/post/requestBody/content/application~1json/schema").valid?(nil)
          assert optional.ref("#/paths/~1items/post/requestBody/content/application~1json/schema").valid?({ "code" => "ok" })
          refute optional.ref("#/paths/~1items/post/requestBody/content/application~1json/schema").valid?({})
          assert optional.ref("#/paths/~1items/post/responses/200/content/application~1json/schema").valid?(nil)
          refute optional.ref("#/paths/~1items/post/responses/201/content/application~1json/schema").valid?(nil)
          assert optional.ref("#/paths/~1items/post/responses/201/content/application~1json/schema").valid?({ "code" => "ok" })
          refute optional.schema("Details").valid?(nil)
        end
      end

      def test_oas30_root_null_branch_is_typed_nullable_enum
        schema = named_details(nullable: true)
        rendered = OAS3::RequestBody.new(
          ApiModel::RequestBody.new(media_types: [media(schema)]),
        ).build.dig("content", "application/json", "schema")

        null_branch = rendered.fetch("anyOf").find { |branch| branch["enum"] == [nil] }

        assert null_branch
        assert_equal "object", null_branch["type"]
        assert null_branch["nullable"]
        refute rendered.key?("nullable")
      end

      def test_oas31_root_null_branch_uses_type_null
        schema = named_details(nullable: true)
        rendered = OAS3::RequestBody.new(
          ApiModel::RequestBody.new(media_types: [media(schema)]),
          nil,
          nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,
          schema_builder: OAS31::Schema,
        ).build.dig("content", "application/json", "schema")

        assert(rendered.fetch("anyOf").any? { |branch| branch["type"] == "null" })
      end

      private

      def named_details(nullable:, description: nil)
        ApiModel::Schema.new(canonical_name: "Details", type: "object", nullable: nullable,
                             description: description,)
      end

      def media(schema)
        ApiModel::MediaType.new(mime_type: "application/json", schema: schema)
      end

      def document(request_body:, responses:, version:)
        {
          "openapi" => version,
          "info" => { "title" => "Test", "version" => "1" },
          "paths" => {
            "/items" => {
              "post" => {
                "requestBody" => request_body,
                "responses" => responses
              }
            }
          },
          "components" => {
            "schemas" => {
              "Details" => {
                "type" => "object",
                "required" => ["code"],
                "properties" => { "code" => { "type" => "string" } }
              }
            }
          }
        }
      end
    end
  end
end
