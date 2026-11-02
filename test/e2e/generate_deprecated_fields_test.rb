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
      expose :described_address, using: AddressEntity, documentation: { deprecated: true, desc: "Old address" }
      expose :restricted_address, using: AddressEntity,
                                  documentation: { deprecated: true, desc: "Restricted", additional_properties: false }
      expose :address, using: AddressEntity
      expose :aliases, documentation: { type: String, is_array: true, deprecated: true }
      expose :legacy do
        expose :id, documentation: { type: Integer }
      end
      expose :meta, documentation: { deprecated: true } do
        expose :flag, documentation: { type: String }
      end
    end

    # Exposure docs that inline a copy of the shared schema; deprecating them
    # must only add the flag.
    INLINE_COPY_DOCS = {
      sample_address: { example: { city: "Paris" } },
      restricted_address: { example: { city: "Paris" }, additional_properties: false }
    }.freeze

    class PlainCopiesEntity < Grape::Entity
      INLINE_COPY_DOCS.each { |key, doc| expose key, using: AddressEntity, documentation: doc }
    end

    class DeprecatedCopiesEntity < Grape::Entity
      INLINE_COPY_DOCS.each { |key, doc| expose key, using: AddressEntity, documentation: doc.merge(deprecated: true) }
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

      desc "Search users"
      params do
        optional :home, type: AddressEntity, documentation: { deprecated: true }
        optional :work, type: AddressEntity
        optional :filter, type: Hash, documentation: { deprecated: true } do
          optional :city, type: String
        end
        optional :geo, type: Hash do
          optional :area, type: Hash, documentation: { deprecated: true } do
            optional :zip, type: String
          end
          optional :lat, type: Float
        end
      end
      get "/users/search" do
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

      desc "Create home"
      params { optional :home, type: AddressEntity }
      post("/homes") { {} }

      desc "Replace home"
      params { optional :home, type: AddressEntity, documentation: { deprecated: true } }
      put("/homes") { {} }

      desc "Plain copies", success: PlainCopiesEntity
      get("/copies") { {} }

      desc "Deprecated copies", success: DeprecatedCopiesEntity
      get("/copies/deprecated") { {} }
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
        props = spec(dialect).dig("paths", "/users", "post", "requestBody", "content", "application/json", "schema",
                                  "properties",)

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

    def test_deprecated_entity_body_property_keeps_body_shape
      oas2_body = ->(verb) { spec(:oas2).dig("paths", "/homes", verb, "parameters").find { |p| p["in"] == "body" } }

      assert_equal "body", oas2_body.call("put")["name"]
      assert_equal oas2_body.call("post"), oas2_body.call("put")

      %i[oas3 oas31].each do |dialect|
        generated = spec(dialect)
        body = ->(verb) { generated.dig("paths", "/homes", verb, "requestBody", "content", "application/json", "schema") }
        expected = body.call("post")
        expected["properties"]["home"] = { "allOf" => [expected["properties"]["home"]], "deprecated" => true }

        assert_equal expected, body.call("put"), "#{dialect}: body stays inline"
        assert_empty generated.dig("components", "schemas").keys.grep(/_Request\z/), "#{dialect}: no named request body"
      end
    end

    def test_deprecated_keeps_inline_copy_attributes
      %i[oas2 oas3 oas31].each do |dialect|
        plain = entity_schema(dialect, /PlainCopiesEntity/).fetch("properties")
        deprecated = entity_schema(dialect, /DeprecatedCopiesEntity/).fetch("properties")

        INLINE_COPY_DOCS.each_key do |key|
          expected = plain.fetch(key.to_s)
          expected = expected.merge("deprecated" => true) unless dialect == :oas2

          assert expected.key?(dialect == :oas31 ? "examples" : "example"), "#{dialect}: #{key} keeps its example"
          assert_equal expected, deprecated.fetch(key.to_s), "#{dialect}: #{key}"
        end
        next if dialect == :oas2

        refute plain.fetch("restricted_address").fetch("additionalProperties"), "#{dialect}: restriction present"
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

        assert_equal({ "allOf" => [address_ref(props)], "deprecated" => true }, props.fetch("old_address"),
                     "#{dialect}: using: exposure",)
        assert_equal(
          { "allOf" => [address_ref(props)], "description" => "Old address", "deprecated" => true },
          props.fetch("described_address"),
          "#{dialect}: description stays next to deprecated, not inside allOf",
        )
        assert_equal(
          address_component(dialect).merge(
            "description" => "Restricted", "additionalProperties" => false, "deprecated" => true,
          ),
          props.fetch("restricted_address"),
          "#{dialect}: metadata a wrapper cannot carry goes on a local copy",
        )
      end
    end

    def test_entity_typed_query_parameter_keeps_inline_schema
      %i[oas3 oas31].each do |dialect|
        params = search_params(dialect)
        home = params.find { |p| p["name"] == "home" }
        work = params.find { |p| p["name"] == "work" }

        assert home["deprecated"], "#{dialect}: home"
        refute work.key?("deprecated"), "#{dialect}: work"
        assert_equal work["schema"], home["schema"], "#{dialect}: deprecated must not change the schema"
      end
    end

    def test_bracket_params_inherit_deprecated_from_ancestors
      %i[oas3 oas31].each do |dialect|
        params = search_params(dialect).to_h { |p| [p["name"], p] }

        assert params.fetch("filter[city]")["deprecated"], "#{dialect}: filter[city]"
        assert params.fetch("geo[area][zip]")["deprecated"], "#{dialect}: geo[area][zip]"
        refute params.fetch("geo[lat]").key?("deprecated"), "#{dialect}: geo[lat]"
      end
    end

    def test_shared_component_is_not_deprecated
      %i[oas3 oas31].each do |dialect|
        address = address_component(dialect)

        refute address.key?("deprecated"), "#{dialect}: AddressEntity component must not be deprecated"
        refute address.key?("description"), "#{dialect}: exposure desc must not leak into the component"
        refute address.key?("additionalProperties"), "#{dialect}: exposure restriction must not leak"
      end
    end

    def test_generated_specs_are_valid
      %i[oas2 oas3 oas31].each do |dialect|
        assert OASValidator.validate!(spec(dialect)), "#{dialect} spec must be valid"
      end
    end

    def test_oas2_shapes
      oas2 = spec(:oas2)
      definitions = oas2.fetch("definitions")
      props = definitions.fetch(definitions.keys.grep(/UserEntity/).first).fetch("properties")

      refute_includes JSON.generate(oas2), "deprecated\":true"
      assert_equal({ "type" => "string" }, props.fetch("login"))
      assert_equal address_ref(props), props.fetch("old_address")
      assert_equal({ "allOf" => [address_ref(props)], "description" => "Old address" }, props.fetch("described_address"))
      assert_equal address_component(:oas2).merge("description" => "Restricted"), props.fetch("restricted_address")
      assert_equal({ "type" => "array", "items" => { "type" => "string" } }, props.fetch("aliases"))
      body = oas2.dig("paths", "/users", "post", "parameters").find { |p| p["in"] == "body" }

      assert_equal "body", body["name"]
      assert_equal address_ref(props), body.dig("schema", "properties", "home")
    end

    private

    def spec(dialect)
      # OAS 2.0 cannot express entity-typed query params and warns when dropping them.
      generated = nil
      capture_grape_oas_log { generated = GrapeOAS.generate(app: UsersAPI, schema_type: dialect) }
      generated
    end

    def address_component(dialect)
      entity_schema(dialect, /AddressEntity/)
    end

    def search_params(dialect)
      spec(dialect).dig("paths", "/users/search", "get", "parameters")
    end

    # The undeprecated `address` exposure is a bare $ref to the shared component.
    def address_ref(props)
      props.fetch("address").tap { |ref| assert_equal ["$ref"], ref.keys }
    end

    def user_schema(dialect)
      entity_schema(dialect, /UserEntity/)
    end

    def entity_schema(dialect, pattern)
      generated = spec(dialect)
      schemas = dialect == :oas2 ? generated["definitions"] : generated.dig("components", "schemas")
      schemas.fetch(schemas.keys.grep(pattern).first)
    end
  end
end
