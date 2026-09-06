# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    class OAS2CompositionExtensionsTest < Minitest::Test
      def setup
        @first = ApiModel::Schema.new(canonical_name: "Example::First", type: "object")
        @second = ApiModel::Schema.new(canonical_name: "Example::Second", type: "object")
      end

      def test_default_keeps_first_reference_without_generated_extensions
        schema = ApiModel::Schema.new(any_of: [@first, @second])

        assert_equal({ "$ref" => "#/definitions/Example_First" }, OAS2::Schema.new(schema).build)
      end

      def test_single_alternative_stays_a_plain_reference_when_opted_in
        %i[one_of any_of].each do |composition|
          schema = ApiModel::Schema.new(**{ composition => [@first] })

          assert_equal({ "$ref" => "#/definitions/Example_First" }, render(schema))
        end
      end

      def test_both_compositions_preserve_their_alternatives
        schema = ApiModel::Schema.new(one_of: [@first, @second], any_of: [@second, @first])
        result = render(schema)

        assert_equal [{ "$ref" => "#/definitions/Example_First" }, { "$ref" => "#/definitions/Example_Second" }], result["x-oneOf"]
        assert_equal result["x-oneOf"].reverse, result["x-anyOf"]
        assert_equal [{ "$ref" => "#/definitions/Example_First" }], result["allOf"]
      end

      def test_typed_composition_preserves_type_and_extensions
        schema = ApiModel::Schema.new(type: "object", any_of: [@first, @second], extensions: { "x-label" => "contact" })
        result = render(schema)

        assert_equal "object", result["type"]
        assert_equal 2, result["x-anyOf"].size
        assert_equal "contact", result["x-label"]
      end

      def test_allof_keeps_existing_precedence
        schema = ApiModel::Schema.new(all_of: [@first], any_of: [@first, @second])
        result = render(schema)

        assert_equal [{ "$ref" => "#/definitions/Example_First" }], result["allOf"]
        refute result.key?("x-anyOf")
      end

      def test_explicit_extension_wins_without_tracking_unused_alternatives
        schema = ApiModel::Schema.new(any_of: [@first, @second], extensions: { "x-anyOf" => [{ "type" => "string" }] })
        tracker = Set.new
        result = OAS2::Schema.new(schema, tracker, composition_extensions: true).build

        assert_equal [{ "type" => "string" }], result["x-anyOf"]
        assert_equal Set["Example::First"], tracker
      end

      def test_named_alternative_preserves_metadata_in_ref_wrapper
        @second.description = "Second variant"
        @second.default = { "code" => "ok" }
        result = render(ApiModel::Schema.new(any_of: [@first, @second]))
        second = result["x-anyOf"].last

        assert_equal "Second variant", second["description"]
        assert_equal({ "code" => "ok" }, second["default"])
        assert_equal [{ "$ref" => "#/definitions/Example_Second" }], second["allOf"]
      end

      def test_inline_nested_compositions_keep_constraints
        number = ApiModel::Schema.new(type: "integer", minimum: 0, maximum: 10)
        nested = ApiModel::Schema.new(one_of: [number, ApiModel::Schema.new(type: "string")])
        result = render(ApiModel::Schema.new(any_of: [@first, nested]))

        assert_equal 0, result.dig("x-anyOf", 1, "x-oneOf", 0, "minimum")
        assert_equal 10, result.dig("x-anyOf", 1, "x-oneOf", 0, "maximum")
      end

      private

      def render(schema)
        OAS2::Schema.new(schema, nil, composition_extensions: true).build
      end
    end
  end
end
