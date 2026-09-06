# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS3NullableCompositionTest < Minitest::Test
      def test_compositions_admit_null_without_weakening_child_validation
        %i[all_of one_of any_of].product([nil, "object"]).each do |composition, type|
          child = ApiModel::Schema.new(type: "object", required: ["code"], properties: {
                                         "code" => ApiModel::Schema.new(type: "string", min_length: 2)
                                       },)
          schema = ApiModel::Schema.new(**{ composition => [child] }, type: type, nullable: true,
                                                                      description: "Optional details", default: { "code" => "ok" },
                                                                      extensions: { "x-purpose" => "details" },)
          rendered = OAS3::Schema.new(schema).build
          validator = document(rendered).schema("Test")

          assert validator.valid?(nil), "#{composition}, type=#{type.inspect} must accept null"
          assert validator.valid?({ "code" => "ok" })
          refute validator.valid?({})
          refute validator.valid?({ "code" => "x" })
          refute validator.valid?(42)
          assert_equal "Optional details", rendered["description"]
          assert_equal({ "code" => "ok" }, rendered["default"])
          assert_equal "details", rendered["x-purpose"]
        end
      end

      def test_nullable_reference_preserves_shared_component_and_enum
        child = ApiModel::Schema.new(canonical_name: "Count", type: "integer", nullable: true,
                                     enum: [1, 2, nil], minimum: 0, maximum: 10,)
        parent = ApiModel::Schema.new(type: "object", properties: { "details" => child })
        rendered = OAS3::Schema.new(parent).build
        validator = document(rendered).schema("Test")

        assert validator.valid?({ "details" => nil })
        assert validator.valid?({ "details" => 1 })
        refute validator.valid?({ "details" => {} })
        refute validator.valid?({ "details" => 3 })
        refute document(rendered).schema("Count").valid?(nil)
      end

      def test_nullable_reference_items_do_not_make_the_array_nullable
        items = ApiModel::Schema.new(canonical_name: "Details", nullable: true)
        rendered = OAS3::Schema.new(ApiModel::Schema.new(type: "array", items: items)).build
        validator = document(rendered).schema("Test")

        assert validator.valid?([nil, { "code" => "ok" }])
        refute validator.valid?(nil)
        refute validator.valid?([{}])
      end

      private

      def document(schema)
        JSONSchemer.openapi({
                              "openapi" => "3.0.3", "info" => { "title" => "Test", "version" => "1" }, "paths" => {},
                              "components" => { "schemas" => {
                                "Test" => schema,
                                "Count" => { "type" => "integer" },
                                "Details" => { "type" => "object", "required" => ["code"],
                                               "properties" => { "code" => { "type" => "string" } } }
                              } }
                            })
      end
    end
  end
end
