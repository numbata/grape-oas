# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Unit tests for ParamSchemaBuilder with array types.
      #
      # Grape stringifies typed arrays (e.g. type: [MyModule::Types::UUID] becomes "[MyModule::Types::UUID]").
      # These tests exercise the schema builder directly with pre-stringified types
      # because Grape >= 3.2 validates types at definition time and rejects unknown strings.
      class ParamSchemaBuilderArrayTest < Minitest::Test
        def teardown
          Object.send(:remove_const, :TestUserEntityForArray) if defined?(TestUserEntityForArray)
        end

        def test_namespaced_type_with_uuid
          schema = ParamSchemaBuilder.build(
            type: "[MyModule::Types::UUID]", documentation: {},
          )

          assert_equal "array", schema.type
          assert_equal "string", schema.items.type
          assert_equal "uuid", schema.items.format
        end

        def test_namespaced_type_with_datetime
          schema = ParamSchemaBuilder.build(
            type: "[MyModule::Types::DateTime]", documentation: {},
          )

          assert_equal "array", schema.type
          assert_equal "string", schema.items.type
          assert_equal "date-time", schema.items.format
        end

        def test_deeply_namespaced_type
          schema = ParamSchemaBuilder.build(
            type: "[Very::Deeply::Nested::Module::Type]", documentation: {},
          )

          assert_equal "array", schema.type
          assert_equal "string", schema.items.type
        end

        def test_entity_in_typed_notation
          user_entity = Class.new(Grape::Entity) do
            expose :id, documentation: { type: Integer }
            expose :name, documentation: { type: String }
          end

          Object.const_set(:TestUserEntityForArray, user_entity) unless defined?(TestUserEntityForArray)

          schema = ParamSchemaBuilder.build(
            type: "[TestUserEntityForArray]", documentation: {},
          )

          assert_equal "array", schema.type
          assert_equal "object", schema.items.type
          assert schema.items.properties.key?("id")
          assert schema.items.properties.key?("name")
        end

        def test_unresolvable_entity_falls_back_to_string
          schema = nil
          capture_grape_oas_log do
            schema = ParamSchemaBuilder.build(
              type: "NonExistent::Module::Entity", documentation: {},
            )
          end

          assert_equal "string", schema.type, "Should fall back to string for unresolvable entity"
        end
      end
    end
  end
end
