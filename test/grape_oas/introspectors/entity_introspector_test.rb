# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorTest < Minitest::Test
      class AddressEntity < Grape::Entity
        expose :city, documentation: { type: String }
      end

      class ProfileEntity < Grape::Entity
        expose :bio, documentation: { type: String, nullable: true }
      end

      class UserEntity < Grape::Entity
        expose :id, documentation: { type: Integer, desc: "User ID", nullable: true }
        expose :name, documentation: { type: String }
        expose :address, using: AddressEntity, documentation: { type: AddressEntity }
        expose :tags, documentation: { type: String, is_array: true, values: %w[a b] }
        expose :nickname, documentation: { type: String, example: "JJ", format: "nickname" }
        expose :profile, using: ProfileEntity, documentation: { type: ProfileEntity }
        def self.documentation
          { "x-entity-root" => "root-ext" }
        end
      end

      def test_builds_properties_and_refs
        schema = Introspectors::EntityIntrospector.new(UserEntity).build_schema

        assert_equal "object", schema.type
        assert_equal "GrapeOAS::Introspectors::EntityIntrospectorTest::UserEntity", schema.canonical_name
        assert_equal %w[address id name nickname profile tags].sort, schema.properties.keys.sort

        id_schema = schema.properties["id"]

        assert_equal "integer", id_schema.type
        assert id_schema.nullable

        addr_schema = schema.properties["address"]

        assert_equal "object", addr_schema.type
        assert_equal "GrapeOAS::Introspectors::EntityIntrospectorTest::AddressEntity", addr_schema.canonical_name

        tags_schema = schema.properties["tags"]

        assert_equal "array", tags_schema.type
        assert_equal %w[a b], tags_schema.items.enum

        nick_schema = schema.properties["nickname"]

        assert_equal "nickname", nick_schema.format
        assert_equal "JJ", nick_schema.examples

        profile = schema.properties["profile"]

        assert_equal "object", profile.type
        assert_includes profile.properties.keys, "bio"

        assert_equal "root-ext", schema.extensions["x-entity-root"]
      end
    end
  end
end
