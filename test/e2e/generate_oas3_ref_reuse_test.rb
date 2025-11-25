# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOAS3RefReuseTest < Minitest::Test
    class UserEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :name, documentation: { type: String }
    end

    class API < Grape::API
      format :json

      params do
        requires :user, type: UserEntity, documentation: { param_type: "body" }
      end
      post "/users", entity: UserEntity do
        {}
      end

      get "/users", entity: UserEntity do
        {}
      end
    end

    def test_reuses_component_schema_for_entity
      schema = GrapeOAS.generate(app: API, schema_type: :oas3)

      components = schema.dig("components", "schemas")

      refute_nil components
      assert_equal 1, components.keys.size
      ref_name = components.keys.first

      post_body = schema["paths"]["/users"]["post"]["requestBody"]["content"]["application/json"]["schema"]
      user_prop = post_body["properties"]["user"]

      assert_equal "#/components/schemas/#{ref_name}", user_prop["$ref"]

      get_resp = schema["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]

      assert_equal "#/components/schemas/#{ref_name}", get_resp["$ref"]
    end
  end
end
