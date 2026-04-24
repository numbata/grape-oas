# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateExposureRequiredDefaultConfigTest < Minitest::Test
    class UserEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :name, documentation: { type: String }
      expose :nickname, documentation: { type: String, required: false }
      expose :email, documentation: { type: String, required: true }
      expose :maybe, documentation: { type: String }, if: ->(_o, _opts) { true }
    end

    class API < Grape::API
      format :json

      desc "Get a user" do
        success UserEntity
      end
      get "/users/:id" do
        {}
      end
    end

    def teardown
      GrapeOAS.entity_exposure_required_default = nil
    end

    # === Default-behavior regression guard: flag defaults to true ===

    def test_default_flag_marks_unconditional_exposures_required
      GrapeOAS.entity_exposure_required_default = nil

      schema = GrapeOAS.generate(app: API, schema_type: :oas3)
      required = schema.dig("components", "schemas", "GrapeOAS_GenerateExposureRequiredDefaultConfigTest_UserEntity", "required")

      assert_includes required, "id"
      assert_includes required, "name"
      assert_includes required, "email"
      refute_includes required, "nickname", "explicit required: false must win"
      refute_includes required, "maybe", "conditional exposures are never required by default"
    end

    # === Opt-out: flag=false strips default-required from unconditional exposures ===

    def test_flag_false_does_not_mark_unconditional_exposures_required
      GrapeOAS.entity_exposure_required_default = false

      schema = GrapeOAS.generate(app: API, schema_type: :oas3)
      component = schema.dig("components", "schemas", "GrapeOAS_GenerateExposureRequiredDefaultConfigTest_UserEntity")
      required = component["required"] || []

      refute_includes required, "id"
      refute_includes required, "name"
      refute_includes required, "nickname"
      refute_includes required, "maybe"
      assert_includes required, "email", "explicit required: true must still mark the property required"
    end

    # === Explicit flag=true matches default ===

    def test_flag_true_matches_default_behavior
      GrapeOAS.entity_exposure_required_default = true

      schema = GrapeOAS.generate(app: API, schema_type: :oas3)
      required = schema.dig("components", "schemas", "GrapeOAS_GenerateExposureRequiredDefaultConfigTest_UserEntity", "required")

      assert_includes required, "id"
      assert_includes required, "name"
      assert_includes required, "email"
      refute_includes required, "nickname"
      refute_includes required, "maybe"
    end
  end
end
