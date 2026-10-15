# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateDeprecatedFieldsTest < Minitest::Test
    class AddressEntity < Grape::Entity
      expose :city, documentation: { type: String }
    end

    class UserEntity < Grape::Entity
      expose :name, documentation: { type: String }
      expose :login, documentation: { type: String, deprecated: true }
      expose :old_address, using: AddressEntity, documentation: { deprecated: true }
      expose :address, using: AddressEntity
      expose :aliases, documentation: { type: String, is_array: true, deprecated: true }
      expose :legacy do
        expose :id, documentation: { type: Integer }
      end
      expose :meta, documentation: { deprecated: true } do
        expose :flag, documentation: { type: String }
      end
    end

    class UsersAPI < Grape::API
      format :json

      desc "List users", success: UserEntity
      params do
        optional :q, type: String
        optional :search, type: String, documentation: { deprecated: true }
      end
      get "/users" do
        []
      end

      desc "Create user", success: UserEntity
      params do
        requires :name, type: String
        optional :nickname, type: String, documentation: { deprecated: true }
        optional :address, type: Hash, documentation: { deprecated: true } do
          optional :city, type: String
        end
        optional :tags, type: Array, documentation: { deprecated: true } do
          optional :label, type: String
        end
        optional :home, type: AddressEntity, documentation: { deprecated: true }
      end
      post "/users" do
        {}
      end
    end

    def test_oas3_marks_deprecated_query_parameter
      %i[oas3 oas31].each do |dialect|
        params = spec(dialect).dig("paths", "/users", "get", "parameters")
        search = params.find { |p| p["name"] == "search" }
        q = params.find { |p| p["name"] == "q" }

        assert search["deprecated"], "#{dialect}: search must be deprecated"
        refute search["schema"].key?("deprecated"), "#{dialect}: deprecated belongs on the parameter only"
        refute q.key?("deprecated"), "#{dialect}: q must not carry deprecated"
      end
    end

    def test_oas3_marks_deprecated_body_properties
      %i[oas3 oas31].each do |dialect|
        props = spec(dialect).dig("components", "schemas", "post_users_Request", "properties")

        assert props.dig("nickname", "deprecated"), "#{dialect}: nickname"
        assert props.dig("address", "deprecated"), "#{dialect}: nested Hash address"
        assert_equal({ "type" => "string" }, props.dig("address", "properties", "city"))
        assert props.dig("tags", "deprecated"), "#{dialect}: nested Array tags"
        refute props.dig("tags", "items").key?("deprecated"), "#{dialect}: tags items"
        refute props.fetch("name").key?("deprecated"), "#{dialect}: name"

        home = props.fetch("home")

        assert home["deprecated"], "#{dialect}: entity-typed home"
        assert_equal 1, home.fetch("allOf").size
        assert home["allOf"].first.key?("$ref")
      end
    end

    def test_oas3_marks_deprecated_entity_properties
      %i[oas3 oas31].each do |dialect|
        props = user_schema(dialect).fetch("properties")

        assert props.dig("login", "deprecated"), "#{dialect}: login"
        refute props.fetch("name").key?("deprecated"), "#{dialect}: name"
        assert props.dig("aliases", "deprecated"), "#{dialect}: is_array exposure"
        assert_equal "array", props.dig("aliases", "type")
        refute props.dig("aliases", "items").key?("deprecated"), "#{dialect}: items must not be deprecated"
        assert props.dig("meta", "deprecated"), "#{dialect}: nesting exposure"
        refute props.fetch("legacy").key?("deprecated"), "#{dialect}: legacy"

        old_address = props.fetch("old_address")

        assert old_address["deprecated"], "#{dialect}: using: exposure"
        assert old_address.fetch("allOf").first.key?("$ref")
        assert props.fetch("address").key?("$ref"), "#{dialect}: plain ref must stay a bare $ref"
      end
    end

    def test_shared_component_is_not_deprecated
      %i[oas3 oas31].each do |dialect|
        schemas = spec(dialect).dig("components", "schemas")
        address = schemas.fetch(schemas.keys.grep(/AddressEntity/).first)

        refute address.key?("deprecated"), "#{dialect}: AddressEntity component must not be deprecated"
      end
    end

    def test_generated_specs_are_valid
      %i[oas2 oas3 oas31].each do |dialect|
        assert OASValidator.validate!(spec(dialect)), "#{dialect} spec must be valid"
      end
    end

    def test_oas2_omits_deprecated
      refute_includes JSON.generate(spec(:oas2)), "deprecated\":true"
    end

    private

    def spec(dialect)
      GrapeOAS.generate(app: UsersAPI, schema_type: dialect)
    end

    def user_schema(dialect)
      schemas = spec(dialect).dig("components", "schemas")
      schemas.fetch(schemas.keys.grep(/UserEntity/).first)
    end
  end
end
