# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      class Schema
        def initialize(schema, ref_tracker = nil)
          @schema = schema
          @ref_tracker = ref_tracker
        end

        def build
          return {} unless @schema

          schema_hash = {
            "type" => @schema.type,
            "format" => @schema.format,
            "description" => @schema.description,
            "properties" => build_properties(@schema.properties),
            "items" => @schema.items ? build_schema_or_ref(@schema.items) : nil
          }
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash.compact
        end

        private

        def build_properties(properties)
          return nil unless properties

          properties.map { |prop| build_schema_or_ref(prop) }
        end

        def build_schema_or_ref(schema)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            { "$ref" => "#/definitions/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker).build
          end
        end
      end
    end
  end
end
