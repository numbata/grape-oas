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
          schema.nullable = nullable if schema.respond_to?(:nullable=)

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
          # evaluates Proc, and sets enum for arrays.
          def apply_values(schema, spec)
            values = spec[:values]
            return unless values

            # Evaluate Proc if provided
            values = values.call if values.respond_to?(:call)

            if values.is_a?(Range)
              apply_range_values(schema, values)
            elsif values.is_a?(Array) && values.any?
              schema.enum = values if schema.respond_to?(:enum=)
            end
          end

          # Converts a Range to minimum/maximum constraints.
          # For numeric ranges (Integer, Float), uses min/max.
          # For other ranges (e.g., 'a'..'z'), expands to enum array.
          def apply_range_values(schema, range)
            first_val = range.first
            last_val = range.last

            if first_val.is_a?(Numeric)
              schema.minimum = first_val if schema.respond_to?(:minimum=)
              schema.maximum = last_val if schema.respond_to?(:maximum=)
            elsif schema.respond_to?(:enum=)
              # Non-numeric range (e.g., 'a'..'z') - expand to enum
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
