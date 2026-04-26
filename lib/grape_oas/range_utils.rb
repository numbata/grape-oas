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
        return unless range

        first_val = range.begin
        last_val = range.end

        return if descending?(first_val, last_val)

        if finite_numeric?(first_val) && target.respond_to?(:minimum=)
          coerced_min = coerce_for_json(first_val)
          target.minimum = coerced_min unless coerced_min.nil?
        end

        return unless finite_numeric?(last_val)

        coerced_max = coerce_for_json(last_val)
        return if coerced_max.nil?

        target.maximum = coerced_max if target.respond_to?(:maximum=)
        target.exclusive_maximum = range.exclude_end? if target.respond_to?(:exclusive_maximum=)
      end

      # Returns true when all non-nil bounds are Numeric (pure numeric range).
      def numeric_range?(range)
        bounds = [range.begin, range.end].compact
        bounds.any? && bounds.all?(Numeric)
      end

      # Applies a Range to a schema as min/max or enum.
      # @param schema [ApiModel::Schema]
      def apply_to_schema(schema, range)
        bounds = [range.begin, range.end].compact
        return if bounds.empty?

        all_numeric = numeric_range?(range)
        any_numeric = bounds.any?(Numeric)
        mixed_numeric = any_numeric && !all_numeric
        numeric_range = all_numeric
        numeric_type = NUMERIC_TYPES.include?(schema.type)

        if mixed_numeric
          GrapeOAS.logger.warn("Mixed-type range #{range} ignored; endpoints must both be numeric or both non-numeric")
        elsif numeric_range && numeric_type
          apply_numeric_range(schema, range)
        elsif numeric_range
          GrapeOAS.logger.warn("Numeric range #{range} ignored on non-numeric schema type '#{schema.type}'")
        elsif !numeric_type
          expanded = expand_range_to_enum(range)
          schema.enum = expanded if expanded
        else
          GrapeOAS.logger.warn("Non-numeric range #{range} ignored on numeric schema type '#{schema.type}'")
        end
      end

      private

      def finite_numeric?(val)
        val.is_a?(Numeric) && val.finite?
      end

      # Coerce BigDecimal to Float so min/max render as JSON numbers, not strings.
      # Returns nil when the result overflows to Infinity.
      def coerce_for_json(val)
        return val unless defined?(BigDecimal) && val.is_a?(BigDecimal)

        coerced = val.to_f
        unless coerced.finite?
          GrapeOAS.logger.warn("BigDecimal value #{val} overflows to Float::INFINITY and cannot be represented in JSON; skipping bound")
          return nil
        end
        if val != BigDecimal(coerced, Float::DIG + 1)
          GrapeOAS.logger.debug("BigDecimal value #{val} lost precision when coerced to Float #{coerced}")
        end
        coerced
      end

      def descending?(first_val, last_val)
        first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val
      end
    end
  end
end
