# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Schema
        def initialize(schema, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD)
          @schema = schema
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
        end

        def build
          return {} unless @schema
          return build_all_of_schema if @schema.all_of && !@schema.all_of.empty?
          return build_one_of_schema if @schema.one_of && !@schema.one_of.empty?
          return build_any_of_schema if @schema.any_of && !@schema.any_of.empty?

          schema_hash = build_base_hash
          apply_examples(schema_hash)
          sanitize_enum_against_type(schema_hash)
          apply_extensions_and_extra_properties(schema_hash)
          apply_all_constraints(schema_hash)
          schema_hash.compact
        end

        def build_base_hash
          schema_hash = {}
          schema_hash["type"] = nullable_type
          schema_hash["format"] = @schema.format
          schema_hash["description"] = @schema.description.to_s if @schema.description
          apply_nullable(schema_hash)
          props = build_properties(@schema.properties)
          schema_hash["properties"] = props if props
          schema_hash["items"] = @schema.items ? build_schema_or_ref(@schema.items) : nil
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash["enum"] = normalize_enum(@schema.enum, schema_hash["type"]) if @schema.enum
          schema_hash
        end

        def apply_examples(schema_hash)
          return unless @schema.examples

          examples = Array(@schema.examples).map { |ex| coerce_example(ex, schema_hash["type"]) }
          schema_hash["example"] = examples.first
        end

        def apply_extensions_and_extra_properties(schema_hash)
          schema_hash.merge!(@schema.extensions) if @schema.extensions
          schema_hash.delete("properties") if schema_hash["properties"]&.empty? || @schema.type != Constants::SchemaTypes::OBJECT
          schema_hash["additionalProperties"] = @schema.additional_properties unless @schema.additional_properties.nil?
          if @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY
            schema_hash["unevaluatedProperties"] = @schema.unevaluated_properties unless @schema.unevaluated_properties.nil?
            schema_hash["$defs"] = @schema.defs if @schema.defs && !@schema.defs.empty?
          end
          schema_hash["discriminator"] = build_discriminator if @schema.discriminator
        end

        def apply_all_constraints(schema_hash)
          apply_numeric_constraints(schema_hash)
          apply_string_constraints(schema_hash)
          apply_array_constraints(schema_hash)
        end

        private

        # Build allOf schema for inheritance
        def build_all_of_schema
          all_of_items = @schema.all_of.map do |item|
            build_schema_or_ref(item)
          end

          result = { "allOf" => all_of_items }
          result["description"] = @schema.description.to_s if @schema.description
          result
        end

        # Build oneOf schema for polymorphism
        def build_one_of_schema
          one_of_items = @schema.one_of.map do |item|
            build_schema_or_ref(item)
          end

          result = { "oneOf" => one_of_items }
          result["description"] = @schema.description.to_s if @schema.description
          result["discriminator"] = build_discriminator if @schema.discriminator
          result
        end

        # Build anyOf schema for polymorphism
        def build_any_of_schema
          any_of_items = @schema.any_of.map do |item|
            build_schema_or_ref(item)
          end

          result = { "anyOf" => any_of_items }
          result["description"] = @schema.description.to_s if @schema.description
          result["discriminator"] = build_discriminator if @schema.discriminator
          result
        end

        # Build OAS3 discriminator object
        def build_discriminator
          return nil unless @schema.discriminator

          if @schema.discriminator.is_a?(Hash)
            # Already in object format with propertyName and optional mapping
            disc = { "propertyName" => @schema.discriminator[:property_name] || @schema.discriminator["propertyName"] }
            mapping = @schema.discriminator[:mapping] || @schema.discriminator["mapping"]
            disc["mapping"] = mapping if mapping && !mapping.empty?
            disc
          else
            # Simple string - convert to object format
            { "propertyName" => @schema.discriminator.to_s }
          end
        end

        def nullable?
          @schema.respond_to?(:nullable) && @schema.nullable
        end

        def nullable_type
          return @schema.type unless nullable? && @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY

          base = Array(@schema.type || Constants::SchemaTypes::STRING)
          (base | ["null"])
        end

        def apply_nullable(schema_hash)
          return unless nullable?

          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            schema_hash["nullable"] = true
          when Constants::NullableStrategy::EXTENSION
            schema_hash["x-nullable"] = true
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
            ref_hash = { "$ref" => "#/components/schemas/#{ref_name}" }
            result = {}
            result["description"] = schema.description.to_s if schema.description
            apply_nullable_to_ref(result, schema)
            if result.empty?
              ref_hash
            else
              result["allOf"] = [ref_hash]
              result
            end
          else
            Schema.new(schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
          end
        end

        def apply_nullable_to_ref(result, schema)
          return unless schema.respond_to?(:nullable) && schema.nullable

          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            result["nullable"] = true
          when Constants::NullableStrategy::EXTENSION
            result["x-nullable"] = true
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

          result = coerced.uniq
          return nil if result.empty?

          result
        end

        def apply_numeric_constraints(hash)
          hash["minimum"] = @schema.minimum unless @schema.minimum.nil?
          hash["maximum"] = @schema.maximum unless @schema.maximum.nil?

          if @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY
            if @schema.exclusive_minimum && !@schema.minimum.nil?
              hash["exclusiveMinimum"] = @schema.minimum
              hash.delete("minimum")
            end
            if @schema.exclusive_maximum && !@schema.maximum.nil?
              hash["exclusiveMaximum"] = @schema.maximum
              hash.delete("maximum")
            end
          else
            hash["exclusiveMinimum"] = @schema.exclusive_minimum if @schema.exclusive_minimum
            hash["exclusiveMaximum"] = @schema.exclusive_maximum if @schema.exclusive_maximum
          end
        end

        def apply_string_constraints(hash)
          hash["minLength"] = @schema.min_length unless @schema.min_length.nil?
          hash["maxLength"] = @schema.max_length unless @schema.max_length.nil?
          hash["pattern"] = @schema.pattern if @schema.pattern
        end

        def apply_array_constraints(hash)
          hash["minItems"] = @schema.min_items unless @schema.min_items.nil?
          hash["maxItems"] = @schema.max_items unless @schema.max_items.nil?
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
          when Constants::SchemaTypes::ARRAY, Constants::SchemaTypes::OBJECT, nil
            hash.delete("enum")
          when Constants::SchemaTypes::INTEGER
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(Integer) }
          when Constants::SchemaTypes::NUMBER
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(Numeric) }
          when Constants::SchemaTypes::BOOLEAN
            hash.delete("enum") unless enum_vals.all? { |v| [true, false].include?(v) }
          else # string and fallback
            hash.delete("enum") unless enum_vals.all? { |v| v.is_a?(String) }
          end
        end

        def coerce_example(example, type_val)
          base_type = if type_val.is_a?(Array)
                        (type_val - ["null"]).first
                      else
                        type_val
                      end

          case base_type
          when Constants::SchemaTypes::INTEGER
            example.to_i
          when Constants::SchemaTypes::NUMBER
            example.to_f
          when Constants::SchemaTypes::BOOLEAN
            example == true || example.to_s == "true"
          when Constants::SchemaTypes::STRING, nil
            example.to_s
          else
            example
          end
        end
      end
    end
  end
end
