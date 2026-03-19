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

    # Applies a Range to a schema as min/max or enum.
    def self.apply_to_schema(schema, range)
      first_val = range.begin
      last_val = range.end
      numeric_range = first_val.is_a?(Numeric) || last_val.is_a?(Numeric)
      numeric_type = NUMERIC_TYPES.include?(schema.type)

      if numeric_range && numeric_type
        return if first_val && last_val && (first_val.is_a?(Numeric) != last_val.is_a?(Numeric))
        return if first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val

        schema.minimum = first_val if first_val.is_a?(Numeric) && schema.respond_to?(:minimum=)
        schema.maximum = last_val if last_val.is_a?(Numeric) && schema.respond_to?(:maximum=)
        # Boolean here; OAS 3.1 exporter converts to numeric at serialization time
        schema.exclusive_maximum = true if range.exclude_end? && last_val && schema.respond_to?(:exclusive_maximum=)
      elsif numeric_range && !numeric_type
        GrapeOAS.logger.warn("Numeric range #{range} ignored on non-numeric schema type '#{schema.type}'")
      elsif !numeric_range && !numeric_type && schema.respond_to?(:enum=)
        expanded = expand_range_to_enum(range)
        schema.enum = expanded if expanded
      elsif !numeric_range && numeric_type
        GrapeOAS.logger.warn("Non-numeric range #{range} ignored on numeric schema type '#{schema.type}'")
      end
    end
  end
end
