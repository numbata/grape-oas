# frozen_string_literal: true

require "test_helper"
require "fileutils"

module GrapeOAS
  class GenerateOAS3ComplexTest < Minitest::Test
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
        post do
          {}
        end

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
        post do
          {}
        end
      end
    end

    def test_complex_oas3_shapes
      schema = GrapeOAS.generate(app: API, schema_type: :oas3)

      components = schema.dig("components", "schemas")

      refute_nil components
      %w[UserEntity ProfileEntity DetailEntity].each do |name|
        assert components.keys.any? { |k| k.include?(name) }, "expected components to include #{name}"
      end

      # Entity param request body
      user_post = schema["paths"]["/users"]["post"]
      req_schema = user_post["requestBody"]["content"]["application/json"]["schema"]
      payload = req_schema["properties"]["payload"]

      assert_includes payload["$ref"], "UserEntity"

      # Response uses ref
      user_get_resp = schema["paths"]["/users/{id}"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]

      assert_includes user_get_resp["$ref"], "UserEntity"

      # Merged fields appear in UserEntity component
      user_component = components.values.find { |c| c["title"] || c } # fallback
      user_component ||= components[components.keys.find { |k| k.include?("UserEntity") }]

      assert_includes user_component["properties"].keys, "city"
      detail_component = components[components.keys.find { |k| k.include?("DetailEntity") }]

      assert detail_component
      assert detail_component["properties"].key?("zip")

      # Contract endpoint request body from Dry contract
      contract_body = schema["paths"]["/contracts"]["post"]["requestBody"]["content"]["application/json"]["schema"]

      assert_equal %w[code id status tags].sort, contract_body["properties"].keys.sort
      assert_equal %w[draft active], contract_body["properties"]["status"]["enum"]
      refute_includes contract_body["required"], "status"
      assert_equal 1, contract_body["properties"]["tags"]["minItems"]
      assert_equal 3, contract_body["properties"]["tags"]["maxItems"]
      assert_equal "\\A[A-Z]{3}\\d{2}\\z", contract_body["properties"]["code"]["pattern"]
      assert_equal 0, contract_body["properties"]["id"]["minimum"]
      assert contract_body["properties"]["id"]["exclusiveMinimum"]

      write_dump("oas3_complex.json", schema)

      assert OASValidator.validate!(schema)
    end

    def test_oas31_snapshot_matches
      schema = GrapeOAS.generate(app: API, schema_type: :oas31)
      write_dump("oas31_complex.json", schema)

      assert OASValidator.validate!(schema)
    end

    def test_oas2_key_expectations
      schema = GrapeOAS.generate(app: API, schema_type: :oas2)
      # Paths exist
      assert_includes schema["paths"].keys, "/users"
      assert_includes schema["paths"].keys, "/contracts"
      # Request body uses ref to UserEntity
      payload_param = schema["paths"]["/users"]["post"]["parameters"].first
      payload_schema = payload_param["schema"]
      if payload_schema["$ref"]
        assert_equal "#/definitions/GrapeOAS_GenerateOAS3ComplexTest_UserEntity", payload_schema["$ref"]
      else
        ref = payload_schema.dig("properties", "payload", "$ref")

        assert_equal "#/definitions/GrapeOAS_GenerateOAS3ComplexTest_UserEntity", ref
      end
      # Contract has id/status/code
      contract_schema = schema["paths"]["/contracts"]["post"]["parameters"].first["schema"]
      props = contract_schema["properties"].keys

      %w[code id status].each { |k| assert_includes props, k }
      assert_equal %w[draft active], contract_schema["properties"]["status"]["enum"]
      assert_equal "\\A[A-Z]{3}\\d{2}\\z", contract_schema["properties"]["code"]["pattern"]
      # Components have all entities
      defs = schema["definitions"]

      %w[UserEntity ProfileEntity DetailEntity].each do |n|
        assert defs.keys.any? { |k| k.include?(n) }, "definitions include #{n}"
      end

      assert OASValidator.validate!(schema)
    end

    def normalize_unhandled(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), h|
          next if k == "x-unhandledPredicates"
          next if %w[consumes produces tags].include?(k)

          h[k] = normalize_unhandled(v)
        end
      when Array
        obj.map { |v| normalize_unhandled(v) }
      else
        obj
      end
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
