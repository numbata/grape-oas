# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Unit tests for ParamSchemaBuilder edge cases.
      #
      # Uses ParamSchemaBuilder directly because Grape >= 3.2 rejects unknown
      # string types at definition time.
      class ParamSchemaBuilderEdgeCasesTest < Minitest::Test
        include LoggerCaptureHelper

        def test_unresolvable_entity_falls_back_to_string
          schema = nil
          capture_grape_oas_log do
            schema = ParamSchemaBuilder.build(
              type: "NonExistent::Module::Entity", documentation: {},
            )
          end

          assert_equal "string", schema.type, "Should fall back to string for unresolvable entity"
        end
      end
    end
  end
end
