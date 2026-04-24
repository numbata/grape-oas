# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Exporter
    module Concerns
      class SchemaIndexerTest < Minitest::Test
        class Host
          include SchemaIndexer

          def initialize
            @ref_schemas = {}
          end
        end

        def setup
          @host = Host.new
        end

        def test_index_schema_indexes_direct_canonical_named_schema
          schema = ApiModel::Schema.new(type: "object", canonical_name: "Direct::Entity")
          index = {}

          @host.index_schema(schema, index)

          assert_same schema, index["Direct::Entity"]
        end

        def test_index_schema_recurses_into_items_for_array_wrapper_without_canonical_name
          nested = ApiModel::Schema.new(type: "object", canonical_name: "Nested::Entity")
          array_wrapper = ApiModel::Schema.new(type: "array", items: nested)
          index = {}

          @host.index_schema(array_wrapper, index)

          assert_same nested, index["Nested::Entity"],
                      "entity reachable only via array wrapper must be indexed"
        end

        def test_index_schema_recurses_through_nested_array_of_array
          deep = ApiModel::Schema.new(type: "object", canonical_name: "Deep::Entity")
          inner_array = ApiModel::Schema.new(type: "array", items: deep)
          outer_array = ApiModel::Schema.new(type: "array", items: inner_array)
          index = {}

          @host.index_schema(outer_array, index)

          assert_same deep, index["Deep::Entity"]
        end

        def test_index_schema_preserves_existing_entry_on_collision
          first = ApiModel::Schema.new(type: "object", canonical_name: "Collision::Entity")
          second = ApiModel::Schema.new(type: "object", canonical_name: "Collision::Entity")
          index = { "Collision::Entity" => first }

          @host.index_schema(second, index)

          assert_same first, index["Collision::Entity"]
        end

        def test_index_schema_noop_on_nil
          index = {}

          @host.index_schema(nil, index)

          assert_empty index
        end

        def test_index_schema_noop_on_schema_without_canonical_name_and_no_items
          schema = ApiModel::Schema.new(type: "string")
          index = {}

          @host.index_schema(schema, index)

          assert_empty index
        end
      end
    end
  end
end
