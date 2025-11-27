# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Schema
        def initialize(schema, ref_tracker = nil, nullable_keyword: true)
          @schema = schema
          @ref_tracker = ref_tracker
          @nullable_keyword = nullable_keyword
        end

        def build
          return {} unless @schema

          schema_hash = {}
          schema_hash["type"] = nullable_type
          schema_hash["format"] = @schema.format
          schema_hash["description"] = @schema.description.to_s if @schema.description
          props = build_properties(@schema.properties)
          schema_hash["properties"] = props if props
          schema_hash["items"] = @schema.items ? build_schema_or_ref(@schema.items) : nil
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash["enum"] = normalize_enum(@schema.enum, schema_hash["type"]) if @schema.enum
          if @schema.examples
            examples = Array(@schema.examples).map { |ex| coerce_example(ex, schema_hash["type"]) }
            schema_hash["example"] = examples.first
          end
          sanitize_enum_against_type(schema_hash)
          schema_hash.merge!(@schema.extensions) if @schema.extensions
          schema_hash.delete("properties") if schema_hash["properties"]&.empty? || @schema.type != "object"
          schema_hash["additionalProperties"] = @schema.additional_properties unless @schema.additional_properties.nil?
          if !@nullable_keyword && !@schema.unevaluated_properties.nil?
            schema_hash["unevaluatedProperties"] = @schema.unevaluated_properties
          end
          schema_hash["$defs"] = @schema.defs if !@nullable_keyword && @schema.defs && !@schema.defs.empty?
          apply_numeric_constraints(schema_hash)
          apply_string_constraints(schema_hash)
          apply_array_constraints(schema_hash)
          schema_hash.compact
        end

        private

        def nullable_type
          return @schema.type unless @schema.respond_to?(:nullable) && @schema.nullable

          if @nullable_keyword
            # OAS3.0 style
            type_hash = { "type" => @schema.type, "nullable" => true }
            return type_hash["type"] if @schema.type.nil?
            return type_hash["type"] if @schema.type.is_a?(Array)

            type_hash["type"]
          else
            base = Array(@schema.type || "string")
            (base | ["null"])
          end
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
            { "$ref" => "#/components/schemas/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker, nullable_keyword: @nullable_keyword).build
          end
        end

        def normalize_enum(enum_vals, type)
          return nil unless enum_vals.is_a?(Array)

          coerced = enum_vals.map do |v|
            case type
            when "integer" then v.to_i if v.respond_to?(:to_i)
            when "number" then v.to_f if v.respond_to?(:to_f)
            else v
            end
          end.compact

          result = coerced.uniq
          return nil if result.empty?

          result
        end

        def apply_numeric_constraints(hash)
          hash["minimum"] = @schema.minimum if @schema.minimum
          hash["maximum"] = @schema.maximum if @schema.maximum

          if @nullable_keyword
            hash["exclusiveMinimum"] = @schema.exclusive_minimum if @schema.exclusive_minimum
            hash["exclusiveMaximum"] = @schema.exclusive_maximum if @schema.exclusive_maximum
          else
            if @schema.exclusive_minimum && @schema.minimum
              hash["exclusiveMinimum"] = @schema.minimum
              hash.delete("minimum")
            end
            if @schema.exclusive_maximum && @schema.maximum
              hash["exclusiveMaximum"] = @schema.maximum
              hash.delete("maximum")
            end
          end
        end

        def apply_string_constraints(hash)
          hash["minLength"] = @schema.min_length if @schema.min_length
          hash["maxLength"] = @schema.max_length if @schema.max_length
          hash["pattern"] = @schema.pattern if @schema.pattern
        end

        def apply_array_constraints(hash)
          hash["minItems"] = @schema.min_items if @schema.min_items
          hash["maxItems"] = @schema.max_items if @schema.max_items
        end

        # Ensure enum values match the declared type; drop enum if incompatible to avoid invalid specs
        def sanitize_enum_against_type(hash)
          enum_vals = hash["enum"]
          type_val = hash["type"]
          return unless enum_vals && type_val

          base_type = if type_val.is_a?(Array)
                        (type_val - ["null"]).first
                      else
                        type_val
                      end

          # Remove enum for unsupported base types or mismatches
          case base_type
          when "array", "object", nil
            hash.delete("enum")
          when "integer"
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(Integer) }
          when "number"
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(Numeric) }
          when "boolean"
            hash.delete("enum") unless enum_vals.all? { |v| v == true || v == false }
          else # string and fallback
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(String) }
          end
        end

        def coerce_example(ex, type_val)
          base_type = if type_val.is_a?(Array)
                        (type_val - ["null"]).first
                      else
                        type_val
                      end

          case base_type
          when "integer"
            ex.to_i
          when "number"
            ex.to_f
          when "boolean"
            ex == true || ex.to_s == "true"
          when "string", nil
            ex.to_s
          else
            ex
          end
        end
      end
    end
  end
end
