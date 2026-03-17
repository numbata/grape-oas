# frozen_string_literal: true

module GrapeOAS
  # Utility methods for converting Range values into OpenAPI-compatible representations.
  module RangeUtils
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
  end
end
