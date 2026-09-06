# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2FormParameterTest < Minitest::Test
      def test_multipart_fields_preserve_types_and_constraints
        schema = ApiModel::Schema.new(type: "object", required: ["upload"], properties: {
                                        "upload" => ApiModel::Schema.new(type: "file", description: "Attachment"),
                                        "count" => ApiModel::Schema.new(type: "integer", minimum: 0, maximum: 10, enum: [0, 10],
                                                                        default: 0,),
                                        "tags" => ApiModel::Schema.new(type: "array", items: ApiModel::Schema.new(type: "string"))
                                      },)
        params = build_parameters(schema, ["multipart/form-data"])

        assert_equal({ "name" => "upload", "in" => "formData", "required" => true,
                       "description" => "Attachment", "type" => "file" }, params[0],)
        assert_equal({ "name" => "count", "in" => "formData", "required" => false,
                       "type" => "integer", "minimum" => 0, "maximum" => 10, "enum" => [0, 10], "default" => 0 }, params[1],)
        assert_equal({ "type" => "string" }, params[2]["items"])
      end

      def test_mixed_encodings_keep_one_body_parameter
        schema = ApiModel::Schema.new(type: "object", properties: { "message" => ApiModel::Schema.new(type: "string") })
        params = build_parameters(schema, ["application/json", "application/x-www-form-urlencoded"])

        assert_equal(["body"], params.map { |param| param["in"] })
      end

      def test_nested_form_objects_raise_instead_of_emitting_invalid_parameters
        schema = ApiModel::Schema.new(type: "object", properties: { "details" => ApiModel::Schema.new(type: "object") })

        error = assert_raises(ArgumentError) { build_parameters(schema, ["multipart/form-data"]) }
        assert_match(/OAS2.*details.*OAS3/, error.message)
      end

      def test_complex_array_items_are_rejected
        [ApiModel::Schema.new(type: "object"), ApiModel::Schema.new(type: "file"),
         ApiModel::Schema.new(type: "string", canonical_name: "Tag")].each do |items|
          schema = ApiModel::Schema.new(type: "object", properties: {
                                          "tags" => ApiModel::Schema.new(type: "array", items: items)
                                        },)

          assert_raises(ArgumentError) { build_parameters(schema, ["multipart/form-data"]) }
        end
      end

      def test_empty_form_has_no_body_parameter
        assert_empty build_parameters(ApiModel::Schema.new(type: "object"), ["application/x-www-form-urlencoded"])
      end

      private

      def build_parameters(schema, consumes)
        media = ApiModel::MediaType.new(mime_type: consumes.first, schema: schema)
        body = ApiModel::RequestBody.new(media_types: [media])
        operation = ApiModel::Operation.new(http_method: "post", consumes: consumes, request_body: body)
        OAS2::Parameter.new(operation).build
      end
    end
  end
end
