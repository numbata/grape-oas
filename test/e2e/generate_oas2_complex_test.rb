# frozen_string_literal: true

require "test_helper"
require "fileutils"

module GrapeOAS
  class GenerateOAS2ComplexTest < Minitest::Test
    require_relative "../support/oas_validator"

    class DetailEntity < Grape::Entity
      expose :city, documentation: { type: String }
      expose :zip, documentation: { type: String, nullable: true }
    end

    class ProfileEntity < Grape::Entity
      expose :bio, documentation: { type: String, nullable: true }
      expose :address, using: DetailEntity, documentation: { type: DetailEntity }
    end

    class UserEntity < Grape::Entity
      expose :id, documentation: { type: Integer }
      expose :name, documentation: { type: String }
      expose :profile, using: ProfileEntity, documentation: { type: ProfileEntity }
      expose :tags, documentation: { type: String, is_array: true }
      expose :extras, using: DetailEntity, merge: true
    end

    class API < Grape::API
      format :json

      namespace :users do
        params do
          requires :payload, type: UserEntity, documentation: { param_type: "body" }
        end
        post { {} }

        params do
          requires :id, type: Integer
        end
        get ":id", entity: UserEntity do
          {}
        end
      end

      namespace :contracts do
        Contract = Dry::Schema.Params do
          required(:id).filled(:integer, gt?: 0)
          optional(:status).maybe(:string, included_in?: %w[draft active])
          optional(:tags).array(:string, min_size?: 1, max_size?: 3)
          optional(:code).maybe(:string, format?: /\A[A-Z]{3}\d{2}\z/)
        end

        desc "Contract endpoint", contract: Contract
        post { {} }
      end
    end

    def test_oas2_complex_shapes
      schema = GrapeOAS.generate(app: API, schema_type: :oas2)

      assert_equal "2.0", schema["swagger"]

      # paths present
      assert_includes schema["paths"].keys, "/users"
      assert_includes schema["paths"].keys, "/contracts"

      # body param references UserEntity
      user_post = schema["paths"]["/users"]["post"]
      payload_param = user_post["parameters"].first

      refute_nil payload_param
      assert_equal "body", payload_param["in"]
      # Grape reuses the body name "body" for entity payloads; accept that
      assert_includes %w[payload body], payload_param["name"]
      ref = payload_param.dig("schema", "$ref") || payload_param.dig("schema", "properties", "payload", "$ref")

      assert_equal "#/definitions/GrapeOAS_GenerateOAS2ComplexTest_UserEntity", ref

      # response uses ref
      user_get_resp = schema["paths"]["/users/{id}"]["get"]["responses"]["200"]["schema"]

      assert_equal "#/definitions/GrapeOAS_GenerateOAS2ComplexTest_UserEntity", user_get_resp["$ref"]

      # contract body param constraints
      contract_param = schema["paths"]["/contracts"]["post"]["parameters"].first
      contract_schema = contract_param["schema"]
      props = contract_schema["properties"]

      assert_equal %w[code id status tags].sort, props.keys.sort
      assert_equal %w[draft active], props["status"]["enum"]
      assert_equal 1, props["tags"]["minItems"]
      assert_equal 3, props["tags"]["maxItems"]
      assert_equal "\\A[A-Z]{3}\\d{2}\\z", props["code"]["pattern"]
      assert_equal 0, props["id"]["minimum"]
      assert props["id"]["exclusiveMinimum"]

      # definitions include entities and merged fields
      defs = schema["definitions"]

      %w[UserEntity ProfileEntity DetailEntity].each do |n|
        assert defs.keys.any? { |k| k.include?(n) }, "definitions include #{n}"
      end
      user_def = defs.values.find { |d| d["properties"]&.key?("extras") } || defs[defs.keys.find do |k|
        k.include?("UserEntity")
      end]

      assert_includes user_def["properties"].keys, "city"

      # validate against metaschema
      assert OASValidator.validate!(schema)
      write_dump("oas2_complex.json", schema)
    end

    def write_dump(filename, payload)
      return unless ENV["WRITE_OAS_SNAPSHOTS"]

      dir = File.join(Dir.pwd, "tmp", "oas_dumps")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, filename)
      File.write(path, JSON.pretty_generate(payload))
      warn "wrote #{path}"
    end
  end
end
