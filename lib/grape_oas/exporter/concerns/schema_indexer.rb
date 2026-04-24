# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module Concerns
      # Shared schema indexing and reference collection logic for OAS2 and OAS3 schema exporters.
      # Handles building schema indexes from operations and collecting nested schema references.
      module SchemaIndexer
        def find_schema_by_canonical_name(canonical_name)
          @ref_schemas[canonical_name] || schema_index[canonical_name]
        end

        def schema_index
          @schema_index ||= build_schema_index
        end

        def build_schema_index
          index = {}
          # Index schemas from operations
          @api.paths.each do |path|
            path.operations.each do |op|
              collect_schemas_from_operation(op, index)
            end
          end
          # Index pre-registered models
          Array(@api.registered_schemas).each do |schema|
            index_schema(schema, index)
          end
          index
        end

        def collect_schemas_from_operation(operation, index)
          Array(operation.parameters).each do |param|
            index_schema(param.schema, index)
          end

          if operation.request_body
            Array(operation.request_body.media_types).each do |media_type|
              index_schema(media_type.schema, index)
            end
          end

          Array(operation.responses).each do |resp|
            Array(resp.media_types).each do |media_type|
              index_schema(media_type.schema, index)
            end
          end
        end

        def index_schema(schema, index)
          return unless schema

          index[schema.canonical_name] ||= schema if schema.respond_to?(:canonical_name) && schema.canonical_name
          index_schema(schema.items, index) if schema.respond_to?(:items) && schema.items
        end

        def collect_refs(schema, pending, seen = Set.new)
          return unless schema

          if schema.respond_to?(:canonical_name) && schema.canonical_name
            return if seen.include?(schema.canonical_name)

            seen << schema.canonical_name
            @ref_schemas[schema.canonical_name] ||= schema
          end

          if schema.respond_to?(:properties) && schema.properties
            schema.properties.each_value do |prop|
              if prop.respond_to?(:canonical_name) && prop.canonical_name
                pending << prop.canonical_name
                @ref_schemas[prop.canonical_name] ||= prop
              end
              collect_refs(prop, pending, seen)
            end
          end
          collect_refs(schema.items, pending, seen) if schema.respond_to?(:items) && schema.items

          # Handle allOf/oneOf/anyOf composition (for inheritance/polymorphism)
          %i[all_of one_of any_of].each do |composition_type|
            next unless schema.respond_to?(composition_type) && schema.send(composition_type)

            schema.send(composition_type).each do |sub_schema|
              if sub_schema.respond_to?(:canonical_name) && sub_schema.canonical_name
                pending << sub_schema.canonical_name
                @ref_schemas[sub_schema.canonical_name] ||= sub_schema
              end
              collect_refs(sub_schema, pending, seen)
            end
          end
        end
      end
    end
  end
end
