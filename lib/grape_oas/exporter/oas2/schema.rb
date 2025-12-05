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

          # Handle allOf composition (for inheritance)
          return build_all_of_schema if @schema.all_of && !@schema.all_of.empty?

          # Handle oneOf/anyOf by using first type (OAS2 doesn't support oneOf/anyOf)
          # Skip if schema has explicit type - use type with extensions instead
          return build_first_of_schema(:one_of) if @schema.one_of && !@schema.one_of.empty? && !@schema.type
          return build_first_of_schema(:any_of) if @schema.any_of && !@schema.any_of.empty? && !@schema.type

          schema_hash = build_base_hash
          apply_constraints(schema_hash)
          apply_extensions(schema_hash)
          schema_hash.compact
        end

        def build_base_hash
          schema_hash = {
            "type" => @schema.type,
            "format" => @schema.format,
            "description" => @schema.description&.to_s,
            "properties" => build_properties(@schema.properties),
            "items" => (@schema.items ? build_schema_or_ref(@schema.items) : nil),
            "enum" => normalize_enum(@schema.enum, @schema.type)
          }
          if schema_hash["properties"].nil? || schema_hash["properties"].empty? || @schema.type != Constants::SchemaTypes::OBJECT
            schema_hash.delete("properties")
          end
          schema_hash["example"] = @schema.examples if @schema.examples
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash["discriminator"] = @schema.discriminator if @schema.discriminator
          schema_hash
        end

        def apply_constraints(schema_hash)
          schema_hash["minLength"] = @schema.min_length if @schema.min_length
          schema_hash["maxLength"] = @schema.max_length if @schema.max_length
          schema_hash["pattern"] = @schema.pattern if @schema.pattern
          schema_hash["minimum"] = @schema.minimum if @schema.minimum
          schema_hash["maximum"] = @schema.maximum if @schema.maximum
          schema_hash["exclusiveMinimum"] = @schema.exclusive_minimum if @schema.exclusive_minimum
          schema_hash["exclusiveMaximum"] = @schema.exclusive_maximum if @schema.exclusive_maximum
          schema_hash["minItems"] = @schema.min_items if @schema.min_items
          schema_hash["maxItems"] = @schema.max_items if @schema.max_items
        end

        def apply_extensions(schema_hash)
          schema_hash.merge!(@schema.extensions) if @schema.extensions
        end

        private

        # Build schema from oneOf/anyOf by using first type (OAS2 doesn't support these)
        # Extensions are merged to allow x-anyOf/x-oneOf for consumers that support them
        def build_first_of_schema(composition_type)
          schemas = @schema.send(composition_type)
          first_schema = schemas.first
          return {} unless first_schema

          # Build the first schema as the fallback
          result = build_schema_or_ref(first_schema)
          result["description"] = @schema.description.to_s if @schema.description
          apply_extensions(result)
          result
        end

        # Build allOf schema for inheritance
        def build_all_of_schema
          all_of_items = @schema.all_of.map do |item|
            build_schema_or_ref(item)
          end

          result = { "allOf" => all_of_items }
          result["description"] = @schema.description.to_s if @schema.description
          result
        end

        def build_properties(properties)
          return nil unless properties
          return nil if properties.empty?

          properties.transform_values do |prop_schema|
            build_schema_or_ref(prop_schema)
          end
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

        def normalize_enum(enum_vals, type)
          return nil unless enum_vals.is_a?(Array)

          coerced = enum_vals.map do |v|
            case type
            when Constants::SchemaTypes::INTEGER then v.to_i if v.respond_to?(:to_i)
            when Constants::SchemaTypes::NUMBER then v.to_f if v.respond_to?(:to_f)
            else v
            end
          end.compact

          coerced.uniq
        end
      end
    end
  end
end
