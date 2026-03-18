# frozen_string_literal: true

module GrapeOAS
  # Utility methods for converting Range values into OpenAPI-compatible representations.
  module RangeUtils
    NUMERIC_TYPES = [Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER].freeze

    # Converts a non-numeric bounded Range to an array for enum values.
    # Returns nil for numeric ranges (should use min/max instead),
    # unbounded (endless/beginless) ranges, empty ranges, or excessively large ranges.
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

    # Applies a Range to a schema as min/max constraints or enum values.
    # Numeric ranges on numeric schema types set minimum/maximum (with exclusive_maximum
    # for three-dot ranges). Non-numeric ranges expand to enum via expand_range_to_enum.
    # Skips numeric ranges on non-numeric types and descending numeric ranges.
    def self.apply_to_schema(schema, range)
      first_val = range.begin
      last_val = range.end
      numeric_range = first_val.is_a?(Numeric) || last_val.is_a?(Numeric)
      numeric_type = NUMERIC_TYPES.include?(schema.type)

      if numeric_range && numeric_type
        # Skip descending numeric ranges (e.g. 10..1)
        return if first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val

        schema.minimum = first_val if first_val && schema.respond_to?(:minimum=)
        schema.maximum = last_val if last_val && schema.respond_to?(:maximum=)
        schema.exclusive_maximum = true if range.exclude_end? && last_val && schema.respond_to?(:exclusive_maximum=)
      elsif !numeric_range && schema.respond_to?(:enum=)
        expanded = expand_range_to_enum(range)
        schema.enum = expanded if expanded
      end
    end
  end
end
