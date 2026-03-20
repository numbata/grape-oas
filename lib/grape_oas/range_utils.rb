# frozen_string_literal: true

module GrapeOAS
  # Utility methods for converting Range values into OpenAPI-compatible representations.
  module RangeUtils
    NUMERIC_TYPES = [Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER].freeze

    # Expands a non-numeric bounded Range to an enum array.
    # Returns nil for numeric, unbounded, empty, or oversized ranges.
    def self.expand_range_to_enum(range)
      return nil if range.begin.nil? || range.end.nil?
      return nil if range.begin.is_a?(Numeric) || range.end.is_a?(Numeric)

      begin
        array = range.first(Constants::MAX_ENUM_RANGE_SIZE + 1)
      rescue TypeError
        return nil
      end

      return nil if array.empty? || array.size > Constants::MAX_ENUM_RANGE_SIZE

      array
    end

    # Extracts numeric constraints from a Range.
    # Returns :exclusive_maximum as true/false (not omitted) when :maximum is present,
    # because PredicateHandler needs explicit false for ast_walker intersection logic.
    # Callers that only care about truthy exclusive_maximum (like apply_to_schema)
    # can simply check `if constraints[:exclusive_maximum]`.
    # @return [Hash] with :minimum, :maximum, :exclusive_maximum
    def self.extract_constraints(range)
      result = {}
      first_val = range.begin
      last_val = range.end

      # Skip descending ranges (e.g. 10..1) — would produce minimum > maximum
      return result if first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val

      result[:minimum] = first_val if first_val.is_a?(Numeric) && first_val.finite?
      if last_val.is_a?(Numeric) && last_val.finite?
        result[:maximum] = last_val
        result[:exclusive_maximum] = range.exclude_end?
      end

      result
    end

    # Applies a Range to a schema as min/max or enum.
    # @param schema [ApiModel::Schema] must respond to #type
    def self.apply_to_schema(schema, range)
      first_val = range.begin
      last_val = range.end
      numeric_range = first_val.is_a?(Numeric) || last_val.is_a?(Numeric)
      numeric_type = NUMERIC_TYPES.include?(schema.type)

      if numeric_range && numeric_type
        # Defensive: Ruby prevents constructing mixed-type ranges, but guard anyway
        return if first_val && last_val && (first_val.is_a?(Numeric) != last_val.is_a?(Numeric))
        return if first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val

        constraints = extract_constraints(range)
        schema.minimum = constraints[:minimum] if constraints[:minimum]
        schema.maximum = constraints[:maximum] if constraints[:maximum]
        # Boolean here; OAS 3.1 exporter converts to numeric at serialization time
        schema.exclusive_maximum = true if constraints[:exclusive_maximum]
      elsif numeric_range && !numeric_type
        warn "[grape-oas] Numeric range #{range} ignored on non-numeric schema type '#{schema.type}'"
      elsif !numeric_range && !numeric_type
        expanded = expand_range_to_enum(range)
        schema.enum = expanded if expanded && schema.respond_to?(:enum=)
      elsif !numeric_range && numeric_type
        warn "[grape-oas] Non-numeric range #{range} ignored on numeric schema type '#{schema.type}'"
      end
    end
  end
end
