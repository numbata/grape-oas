# frozen_string_literal: true

module GrapeOAS
  # Converts Range values into OpenAPI-compatible representations.
  class RangeUtils
    NUMERIC_TYPES = [Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER].freeze

    class << self
      # Expands a non-numeric bounded Range to an enum array.
      # Returns nil for numeric, unbounded, empty, or oversized ranges.
      def expand_range_to_enum(range)
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

      # Writes numeric range constraints directly to any object with
      # minimum=/maximum=/exclusive_maximum= setters (Schema, ConstraintSet, etc).
      # Skips descending and infinite bounds.
      def apply_numeric_range(target, range)
        first_val = range.begin
        last_val = range.end

        return if descending?(first_val, last_val)

        target.minimum = first_val if finite_numeric?(first_val)
        return unless finite_numeric?(last_val)

        target.maximum = last_val
        target.exclusive_maximum = range.exclude_end?
      end

      # Applies a Range to a schema as min/max or enum.
      # @param schema [ApiModel::Schema]
      def apply_to_schema(schema, range)
        numeric_range = range.begin.is_a?(Numeric) || range.end.is_a?(Numeric)
        numeric_type = NUMERIC_TYPES.include?(schema.type)

        if numeric_range && numeric_type
          apply_numeric_range(schema, range)
        elsif numeric_range
          warn "[grape-oas] Numeric range #{range} ignored on non-numeric schema type '#{schema.type}'"
        elsif !numeric_type
          expanded = expand_range_to_enum(range)
          schema.enum = expanded if expanded
        else
          warn "[grape-oas] Non-numeric range #{range} ignored on numeric schema type '#{schema.type}'"
        end
      end

      private

      def finite_numeric?(val)
        val.is_a?(Numeric) && val.finite?
      end

      def descending?(first_val, last_val)
        first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val
      end
    end
  end
end
