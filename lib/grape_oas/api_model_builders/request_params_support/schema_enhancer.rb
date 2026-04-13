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
          nullable = extract_nullable(doc)

          schema.description ||= doc[:desc]
          # Preserve existing nullable: true (e.g., from [Type, Nil] optimization)
          schema.nullable = (schema.nullable || nullable) if schema.respond_to?(:nullable=)

          apply_additional_properties(schema, doc)
          apply_format_and_example(schema, doc)
          SchemaConstraints.apply(schema, doc)
          apply_values(schema, spec)
          apply_default(schema, spec, doc)
        end

        # Extracts nullable flag from a documentation hash.
        #
        # @param doc [Hash] the documentation hash
        # @return [Boolean] true if nullable
        def self.extract_nullable(doc)
          doc[:nullable] || (doc[:x].is_a?(Hash) && doc[:x][:nullable]) || false
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

          def apply_default(schema, spec, doc)
            return unless schema.respond_to?(:default=)

            if spec.key?(:default)
              schema.default = spec[:default]
            elsif doc.key?(:default)
              schema.default = doc[:default]
            end
          end

          def apply_format_and_example(schema, doc)
            schema.format = doc[:format] if doc[:format] && schema.respond_to?(:format=)
            schema.examples = doc[:example] if doc[:example] && schema.respond_to?(:examples=)
          end

          def apply_values(schema, spec)
            values = ValuesNormalizer.normalize(spec[:values], context: "parameter values")
            return unless values

            if values.is_a?(Range)
              if one_of_schema?(schema)
                schema.one_of.each do |variant|
                  next if null_type_schema?(variant)
                  next unless range_compatible_with_schema?(values, variant)

                  RangeUtils.apply_to_schema(variant, values)
                end
              elsif array_schema_with_items?(schema)
                RangeUtils.apply_to_schema(schema.items, values)
              else
                RangeUtils.apply_to_schema(schema, values)
              end
            elsif values.is_a?(Array) && !values.empty?
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
                variant.enum = compatible_values if !compatible_values.empty? && variant.respond_to?(:enum=)
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
            schema.respond_to?(:one_of) && schema.one_of.is_a?(Array) && !schema.one_of.empty?
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

          def extract_defs(doc)
            doc[:defs] || doc[:$defs]
          end

          def range_compatible_with_schema?(range, schema)
            numeric_type = RangeUtils::NUMERIC_TYPES.include?(schema.type)
            RangeUtils.numeric_range?(range) ? numeric_type : !numeric_type
          end
        end
      end
    end
  end
end
