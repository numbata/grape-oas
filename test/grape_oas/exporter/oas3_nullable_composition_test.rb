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

      def test_discriminators_stay_with_the_original_composition
        %i[one_of any_of].product(%i[keyword type_array]).each do |composition, strategy|
          child = ApiModel::Schema.new(canonical_name: "Details")
          schema = ApiModel::Schema.new(**{ composition => [child] }, nullable: true, discriminator: "code")
          rendered = OAS3::Schema.new(schema, nil, nullable_strategy: strategy).build
          branch = rendered.fetch("anyOf").first
          key = composition == :one_of ? "oneOf" : "anyOf"

          refute rendered.key?("discriminator")
          assert_equal({ "propertyName" => "code" }, branch["discriminator"])
          assert_equal [{ "$ref" => "#/components/schemas/Details" }], branch[key]
          version = strategy == :keyword ? "3.0.3" : "3.1.0"

          assert document(rendered, version: version).schema("Test").valid?(nil)
        end
      end

      def test_oas31_nullable_reference_items_keep_array_non_nullable
        items = ApiModel::Schema.new(canonical_name: "Details", nullable: true)
        rendered = OAS31::Schema.new(ApiModel::Schema.new(type: "array", items: items), nil,
                                     nullable_strategy: Constants::NullableStrategy::TYPE_ARRAY,).build
        validator = document(rendered, version: "3.1.0").schema("Test")

        assert validator.valid?([nil, { "code" => "ok" }])
        refute validator.valid?(nil)
        refute validator.valid?([{}])
      end

      def test_extension_strategy_keeps_nullable_on_reference_items
        items = ApiModel::Schema.new(canonical_name: "Details", nullable: true)
        rendered = OAS3::Schema.new(ApiModel::Schema.new(type: "array", items: items), nil,
                                    nullable_strategy: Constants::NullableStrategy::EXTENSION,).build

        refute rendered.key?("x-nullable")
        assert rendered.fetch("items")["x-nullable"]
      end

      def test_invalid_composition_override_has_a_clear_error
        schema = ApiModel::Schema.new(any_of: [ApiModel::Schema.new(type: "string")], nullable: true,
                                      extensions: { "anyOf" => "invalid" },)

        error = assert_raises(ArgumentError) { OAS3::Schema.new(schema).build }
        assert_equal "anyOf must be an Array of schemas", error.message
      end

      def test_typeless_schema_omits_ineffective_nullable_keyword
        rendered = OAS3::Schema.new(ApiModel::Schema.new(nullable: true)).build

        refute rendered.key?("nullable")
      end

      private

      def document(schema, version: "3.0.3")
        JSONSchemer.openapi({
                              "openapi" => version, "info" => { "title" => "Test", "version" => "1" }, "paths" => {},
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
