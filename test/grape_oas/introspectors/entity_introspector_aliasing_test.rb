# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    # Tests for entity exposure aliasing with `as:` option
    class EntityIntrospectorAliasingTest < Minitest::Test
      # === Basic aliasing ===

      class BasicAliasEntity < Grape::Entity
        expose :internal_name, as: :public_name, documentation: { type: String }
        expose :another_field, documentation: { type: Integer }
      end

      def test_basic_alias_uses_as_name_in_properties
        schema = EntityIntrospector.new(BasicAliasEntity).build_schema

        # Should use aliased name, not internal name
        assert_includes schema.properties.keys, "public_name"
        refute_includes schema.properties.keys, "internal_name"
        assert_includes schema.properties.keys, "another_field"
      end

      # === Special characters in alias ===

      class SpecialCharAliasEntity < Grape::Entity
        expose :responses, as: :$responses, documentation: { type: String }
        expose :at_field, as: :@field, documentation: { type: String }
      end

      def test_special_character_alias_preserved
        schema = EntityIntrospector.new(SpecialCharAliasEntity).build_schema

        # Special characters should be preserved in property names
        assert_includes schema.properties.keys, "$responses"
        assert_includes schema.properties.keys, "@field"
      end

      # === Alias with nested entity ===

      class NestedEntity < Grape::Entity
        expose :value, documentation: { type: Integer }
      end

      class AliasWithNestedEntity < Grape::Entity
        expose :data, as: :aliased_data, using: NestedEntity, documentation: { type: NestedEntity }
      end

      def test_alias_with_nested_entity
        schema = EntityIntrospector.new(AliasWithNestedEntity).build_schema

        assert_includes schema.properties.keys, "aliased_data"
        refute_includes schema.properties.keys, "data"

        aliased = schema.properties["aliased_data"]

        assert_equal "object", aliased.type
      end

      # === Alias with array of entities ===

      class ItemEntity < Grape::Entity
        expose :id, documentation: { type: Integer }
      end

      class AliasWithArrayEntity < Grape::Entity
        expose :items, as: :results, using: ItemEntity, documentation: { type: ItemEntity, is_array: true }
      end

      def test_alias_with_array_of_entities
        schema = EntityIntrospector.new(AliasWithArrayEntity).build_schema

        assert_includes schema.properties.keys, "results"
        refute_includes schema.properties.keys, "items"

        results = schema.properties["results"]

        assert_equal "array", results.type
      end

      # === Multiple aliases ===

      class MultipleAliasEntity < Grape::Entity
        expose :field_a, as: :alpha, documentation: { type: String }
        expose :field_b, as: :beta, documentation: { type: String }
        expose :field_c, as: :gamma, documentation: { type: String }
      end

      def test_multiple_aliases
        schema = EntityIntrospector.new(MultipleAliasEntity).build_schema

        assert_includes schema.properties.keys, "alpha"
        assert_includes schema.properties.keys, "beta"
        assert_includes schema.properties.keys, "gamma"
        refute_includes schema.properties.keys, "field_a"
        refute_includes schema.properties.keys, "field_b"
        refute_includes schema.properties.keys, "field_c"
      end

      # === Symbol alias ===

      class SymbolAliasEntity < Grape::Entity
        expose :name, as: :title, documentation: { type: String }
      end

      def test_symbol_alias
        schema = EntityIntrospector.new(SymbolAliasEntity).build_schema

        assert_includes schema.properties.keys, "title"
        refute_includes schema.properties.keys, "name"
      end
    end
  end
end
