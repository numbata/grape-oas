# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorDocumentationTest < Minitest::Test
      def test_string_root_keys_match_symbol_keys_without_mutating_documentation
        nested = { "field" => { "type" => "string" } }.freeze
        documentation = {
          "nullable" => true,
          "description" => "Root description",
          "additional_properties" => false,
          "unevaluated_properties" => false,
          "$defs" => nested,
          "x-label" => nested
        }.freeze
        schema = schema_for(documentation)

        assert schema.nullable
        assert_equal "Root description", schema.description
        refute_nil schema.additional_properties
        refute schema.additional_properties
        refute_nil schema.unevaluated_properties
        refute schema.unevaluated_properties
        assert_same nested, schema.defs
        assert_same nested, schema.extensions["x-label"]
        assert documentation.key?("nullable")
        refute documentation.key?(:nullable)
      end

      def test_string_x_key_normalizes_only_the_root
        assert schema_for("x" => { nullable: true }).nullable
        refute schema_for("x" => { "nullable" => true }).nullable
      end

      def test_symbol_empty_and_nil_documentation_remain_supported
        assert schema_for(nullable: true).nullable
        refute schema_for(nullable: false).nullable
        refute schema_for({}).nullable
        refute schema_for(nil).nullable
      end

      def test_root_example_is_applied_to_the_schema
        example = { id: 1, name: "Rex" }

        assert_equal example, schema_for(example: example).examples
        assert_equal example, schema_for("example" => example).examples
      end

      def test_root_false_example_is_preserved
        refute schema_for(example: false).examples
        refute_nil schema_for(example: false).examples
      end

      def test_schema_has_no_examples_without_root_example
        assert_nil schema_for(description: "No example").examples
      end

      private

      def schema_for(documentation)
        entity = Class.new(Grape::Entity)
        entity.define_singleton_method(:documentation) { documentation }
        EntityIntrospector.build_schema(entity)
      end
    end
  end
end
