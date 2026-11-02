# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class OasUtilitiesDeprecatedTest < Minitest::Test
      def test_shared_component_is_wrapped_and_left_unchanged
        component = ApiModel::Schema.new(type: "object", canonical_name: "Address")

        result = Concerns::OasUtilities.apply_deprecated(component, { deprecated: true })

        refute_same component, result
        assert result.deprecated
        assert_nil result.canonical_name
        assert_equal [component], result.all_of
        refute component.deprecated
      end

      def test_inline_schema_is_marked_in_place
        schema = ApiModel::Schema.new(type: "string")

        result = Concerns::OasUtilities.apply_deprecated(schema, { deprecated: true })

        assert_same schema, result
        assert schema.deprecated
        assert_nil schema.all_of
      end

      def test_schema_is_untouched_without_the_flag
        component = ApiModel::Schema.new(type: "object", canonical_name: "Address")

        [{}, { deprecated: false }].each do |doc|
          result = Concerns::OasUtilities.apply_deprecated(component, doc)

          assert_same component, result
          refute component.deprecated
        end
      end
    end
  end
end
