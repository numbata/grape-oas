# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Applies enhancements (constraints, format, examples, etc.) to a schema.
      class SchemaEnhancer
        # Applies all enhancements to a schema based on spec and documentation.
        #
        # @param schema [ApiModel::Schema] the schema to enhance
        # @param spec [Hash] the parameter specification
        # @param doc [Hash] the documentation hash
        def self.apply(schema, spec, doc)
          nullable = extract_nullable(spec, doc)

          schema.description ||= doc[:desc]
          # Preserve existing nullable: true (e.g., from [Type, Nil] optimization)
          schema.nullable = (schema.nullable || nullable) if schema.respond_to?(:nullable=)

          apply_additional_properties(schema, doc)
          apply_format_and_example(schema, doc)
          apply_constraints(schema, doc)
          apply_values(schema, spec)
        end

        # Extracts nullable flag from spec and documentation.
        #
        # @param spec [Hash] the parameter specification
        # @param doc [Hash] the documentation hash
        # @return [Boolean] true if nullable
        def self.extract_nullable(spec, doc)
          spec[:allow_nil] || spec[:nullable] || doc[:nullable] || false
        end

        class << self
          private

          def apply_additional_properties(schema, doc)
            if doc.key?(:additional_properties) && schema.respond_to?(:additional_properties=)
              schema.additional_properties = doc[:additional_properties]
            end
            if doc.key?(:unevaluated_properties) && schema.respond_to?(:unevaluated_properties=)
              schema.unevaluated_properties = doc[:unevaluated_properties]
            end
            defs = extract_defs(doc)
            schema.defs = defs if defs.is_a?(Hash) && schema.respond_to?(:defs=)
          end

          def apply_format_and_example(schema, doc)
            schema.format = doc[:format] if doc[:format] && schema.respond_to?(:format=)
            schema.examples = doc[:example] if doc[:example] && schema.respond_to?(:examples=)
          end

          def apply_constraints(schema, doc)
            schema.minimum = doc[:minimum] if doc.key?(:minimum) && schema.respond_to?(:minimum=)
            schema.maximum = doc[:maximum] if doc.key?(:maximum) && schema.respond_to?(:maximum=)
            schema.min_length = doc[:min_length] if doc.key?(:min_length) && schema.respond_to?(:min_length=)
            schema.max_length = doc[:max_length] if doc.key?(:max_length) && schema.respond_to?(:max_length=)
            schema.pattern = doc[:pattern] if doc.key?(:pattern) && schema.respond_to?(:pattern=)
          end

          # Applies values from spec[:values] - converts Range to min/max,
          # evaluates Proc (arity 0), and sets enum for arrays.
          # Skips Proc/Lambda validators (arity > 0) used for custom validation.
          # For array schemas, applies enum to items (since values constrain array elements).
          # For oneOf schemas, applies enum to each non-null variant.
          def apply_values(schema, spec)
            values = spec[:values]
            return unless values

            # Handle Hash format { value: ..., message: ... } - extract the value
            values = values[:value] if values.is_a?(Hash) && values.key?(:value)

            # Handle Proc/Lambda
            if values.respond_to?(:call)
              # Skip validators (arity > 0) - they validate individual values
              return if values.arity != 0

              # Evaluate arity-0 procs - they return enum arrays
              values = values.call
            end

            if values.is_a?(Range)
              apply_range_values(schema, values)
            elsif values.is_a?(Array) && values.any?
              apply_enum_values(schema, values)
            end
          end

          def apply_enum_values(schema, values)
            # For oneOf schemas, apply enum to each variant that supports enum
            if one_of_schema?(schema)
              schema.one_of.each do |variant|
                # Skip null types - they don't have enums
                next if null_type_schema?(variant)

                # Filter values to those compatible with this variant's type
                compatible_values = filter_compatible_values(variant, values)

                # Only apply enum if there are compatible values
                if compatible_values.any? && variant.respond_to?(:enum=)
                  variant.enum = compatible_values
                end
              end
            elsif array_schema_with_items?(schema)
              # For array schemas, apply enum to items (values constrain array elements)
              schema.items.enum = values if schema.items.respond_to?(:enum=)
            elsif schema.respond_to?(:enum=)
              # For regular schemas, apply enum directly
              schema.enum = values
            end
          end

          def one_of_schema?(schema)
            schema.respond_to?(:one_of) && schema.one_of.is_a?(Array) && schema.one_of.any?
          end

          def null_type_schema?(schema)
            return false unless schema.respond_to?(:type)

            schema.type.nil? || schema.type == "null"
          end

          def array_schema_with_items?(schema)
            schema.respond_to?(:type) &&
              schema.type == Constants::SchemaTypes::ARRAY &&
              schema.respond_to?(:items) &&
              schema.items
          end

          # Filters enum values to those compatible with the schema variant's type.
          # For mixed-type enums like ["a", 1], returns only values matching the variant type.
          def filter_compatible_values(schema, values)
            return values unless schema.respond_to?(:type) && schema.type
            return [] if values.nil? || values.empty?

            case schema.type
            when Constants::SchemaTypes::STRING,
                 Constants::SchemaTypes::INTEGER,
                 Constants::SchemaTypes::NUMBER,
                 Constants::SchemaTypes::BOOLEAN
              values.select { |value| enum_value_compatible_with_type?(schema.type, value) }
            else
              values # Return all values for unknown types
            end
          end

          # Checks if a single enum value is compatible with the given schema type.
          def enum_value_compatible_with_type?(schema_type, value)
            case schema_type
            when Constants::SchemaTypes::STRING
              value.is_a?(String) || value.is_a?(Symbol)
            when Constants::SchemaTypes::INTEGER
              value.is_a?(Integer)
            when Constants::SchemaTypes::NUMBER
              value.is_a?(Numeric)
            when Constants::SchemaTypes::BOOLEAN
              [true, false].include?(value)
            else
              true
            end
          end

          # Converts a Range to minimum/maximum constraints.
          # For numeric ranges (Integer, Float), uses min/max.
          # For other ranges (e.g., 'a'..'z'), expands to enum array.
          # Handles endless/beginless ranges (e.g., 1.., ..10).
          def apply_range_values(schema, range)
            first_val = range.begin
            last_val = range.end

            if first_val.is_a?(Numeric) || last_val.is_a?(Numeric)
              schema.minimum = first_val if first_val && schema.respond_to?(:minimum=)
              schema.maximum = last_val if last_val && schema.respond_to?(:maximum=)
            elsif first_val && last_val && schema.respond_to?(:enum=)
              # Non-numeric bounded range (e.g., 'a'..'z') - expand to enum
              schema.enum = range.to_a
            end
          end

          def extract_defs(doc)
            doc[:defs] || doc[:$defs]
          end
        end
      end
    end
  end
end
