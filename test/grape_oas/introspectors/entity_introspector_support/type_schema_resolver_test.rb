# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      class TypeSchemaResolverTest < Minitest::Test
        # Minimal entity used in string-resolution tests — must be defined at
        # constant-lookup scope (Object) so const_defined?/const_get can find it.
        class ResolverTestEntity < Grape::Entity
          expose :id, documentation: { type: Integer }
        end

        def setup
          @stack = []
          @registry = {}
          @resolver = TypeSchemaResolver.new(stack: @stack, registry: @registry)
        end

        # === nil type falls back to string schema ===

        def test_nil_type_returns_string_schema
          schema = @resolver.build_exposure_base_schema(nil)

          assert_equal Constants::SchemaTypes::STRING, schema.type
        end

        # === known primitive Class resolves correctly ===

        def test_integer_class_produces_integer_schema
          schema = @resolver.build_exposure_base_schema(Integer)

          assert_equal Constants::SchemaTypes::INTEGER, schema.type
        end

        def test_string_class_produces_string_schema
          schema = @resolver.build_exposure_base_schema(String)

          assert_equal Constants::SchemaTypes::STRING, schema.type
        end

        # === Hash / Hash class produces object schema ===

        def test_hash_class_produces_object_schema
          schema = @resolver.build_exposure_base_schema(Hash)

          assert_equal Constants::SchemaTypes::OBJECT, schema.type
        end

        def test_hash_instance_produces_object_schema
          schema = @resolver.build_exposure_base_schema({})

          assert_equal Constants::SchemaTypes::OBJECT, schema.type
        end

        # === Array class produces array schema with string items ===

        def test_array_class_produces_array_of_strings
          schema = @resolver.build_exposure_base_schema(Array)

          assert_equal Constants::SchemaTypes::ARRAY, schema.type
          assert_equal Constants::SchemaTypes::STRING, schema.items.type
        end

        def test_array_literal_wraps_inner_type
          schema = @resolver.build_exposure_base_schema([Integer])

          assert_equal Constants::SchemaTypes::ARRAY, schema.type
          assert_equal Constants::SchemaTypes::INTEGER, schema.items.type
        end

        # === String-to-entity resolution with a valid entity class ===

        def test_string_type_resolving_to_entity_produces_object_schema
          full_name = "#{self.class}::ResolverTestEntity"
          schema = @resolver.build_exposure_base_schema(full_name)

          assert_equal Constants::SchemaTypes::OBJECT, schema.type
          assert_includes schema.properties.keys, "id"
        end

        # === String-to-entity resolution with an invalid constant name ===

        def test_invalid_constant_name_does_not_raise
          schema = @resolver.build_exposure_base_schema("123InvalidName!")

          # Must not raise; falls back to string schema
          assert_equal Constants::SchemaTypes::STRING, schema.type
        end

        def test_undefined_constant_name_does_not_raise
          schema = @resolver.build_exposure_base_schema("Totally::Nonexistent::Entity")

          assert_equal Constants::SchemaTypes::STRING, schema.type
        end

        # === Grape::Entity class type produces object schema via introspection ===

        def test_grape_entity_class_type_produces_object_schema
          schema = @resolver.build_exposure_base_schema(ResolverTestEntity)

          assert_equal Constants::SchemaTypes::OBJECT, schema.type
          assert_includes schema.properties.keys, "id"
        end

        # === resolve_grape_entity_class ===

        def test_resolve_grape_entity_class_returns_entity_when_using_set
          opts = { using: ResolverTestEntity }
          doc = {}

          assert_equal ResolverTestEntity, @resolver.resolve_grape_entity_class(opts, doc)
        end

        def test_resolve_grape_entity_class_returns_nil_for_plain_class
          opts = { using: String }
          doc = {}

          assert_nil @resolver.resolve_grape_entity_class(opts, doc)
        end

        def test_resolve_grape_entity_class_returns_nil_when_no_type
          assert_nil @resolver.resolve_grape_entity_class({}, {})
        end

        # The `rescue NameError` branch in resolve_entity_from_string (type_schema_resolver.rb)
        # guards against a race condition where const_defined? returns true but const_get
        # subsequently raises NameError (e.g. concurrent autoload failure). This cannot be
        # triggered deterministically in a unit test without unsafe global monkey-patching
        # of Object.const_get. Accepted as an untestable defensive branch.
      end
    end
  end
end
