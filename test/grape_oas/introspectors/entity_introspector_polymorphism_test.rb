# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    # Tests for polymorphism support (allOf, discriminator, inheritance)
    class EntityIntrospectorPolymorphismTest < Minitest::Test
      # === Basic discriminator in parent entity ===

      class Pet < Grape::Entity
        expose :type, documentation: {
          type: String,
          is_discriminator: true,
          required: true
        }
        expose :name, documentation: { type: String, required: true }
      end

      class Cat < Pet
        expose :hunting_skill, documentation: {
          type: String,
          desc: "The measured skill for hunting"
        }
      end

      class Dog < Pet
        expose :breed, documentation: { type: String }
        expose :pack_size, documentation: { type: Integer }
      end

      def test_parent_entity_has_discriminator
        schema = EntityIntrospector.new(Pet).build_schema

        assert_equal "object", schema.type
        assert_equal "type", schema.discriminator
        assert_includes schema.properties.keys, "type"
        assert_includes schema.properties.keys, "name"
      end

      def test_child_entity_uses_all_of
        schema = EntityIntrospector.new(Cat).build_schema

        refute_nil schema.all_of, "Child entity should use allOf"
        assert_equal 2, schema.all_of.length

        # First item should be parent ref
        parent_schema = schema.all_of[0]
        assert_equal Pet.name, parent_schema.canonical_name

        # Second item should be child-specific properties
        child_schema = schema.all_of[1]
        assert_includes child_schema.properties.keys, "hunting_skill"
        refute_includes child_schema.properties.keys, "type"
        refute_includes child_schema.properties.keys, "name"
      end

      def test_another_child_entity_uses_all_of
        schema = EntityIntrospector.new(Dog).build_schema

        refute_nil schema.all_of
        assert_equal 2, schema.all_of.length

        child_schema = schema.all_of[1]
        assert_includes child_schema.properties.keys, "breed"
        assert_includes child_schema.properties.keys, "pack_size"
      end

      # === Multi-level inheritance ===

      class Animal < Grape::Entity
        expose :species, documentation: {
          type: String,
          is_discriminator: true,
          required: true
        }
        expose :age, documentation: { type: Integer }
      end

      class Mammal < Animal
        expose :fur_color, documentation: { type: String }
      end

      def test_multi_level_inheritance
        schema = EntityIntrospector.new(Mammal).build_schema

        refute_nil schema.all_of
        # Should reference Animal (parent with discriminator)
        parent_schema = schema.all_of[0]
        assert_equal Animal.name, parent_schema.canonical_name
      end

      # === Inheritance without discriminator (should flatten) ===

      class BaseModel < Grape::Entity
        expose :id, documentation: { type: Integer }
        expose :created_at, documentation: { type: String }
      end

      class UserModel < BaseModel
        expose :email, documentation: { type: String }
      end

      def test_inheritance_without_discriminator_flattens
        schema = EntityIntrospector.new(UserModel).build_schema

        # Without discriminator, properties should be flattened
        assert_nil schema.all_of
        assert_includes schema.properties.keys, "id"
        assert_includes schema.properties.keys, "created_at"
        assert_includes schema.properties.keys, "email"
      end

      # === Required fields in discriminator ===

      def test_discriminator_field_marked_required
        schema = EntityIntrospector.new(Pet).build_schema

        assert_includes schema.required, "type"
        assert_includes schema.required, "name"
      end

      # === Entity with discriminator but no children ===

      class StandaloneEntity < Grape::Entity
        expose :kind, documentation: {
          type: String,
          is_discriminator: true
        }
        expose :value, documentation: { type: String }
      end

      def test_standalone_discriminator_entity
        schema = EntityIntrospector.new(StandaloneEntity).build_schema

        assert_equal "kind", schema.discriminator
        assert_nil schema.all_of
        assert_includes schema.properties.keys, "kind"
        assert_includes schema.properties.keys, "value"
      end
    end
  end
end
