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

        target.minimum = first_val if finite_numeric?(first_val) && target.respond_to?(:minimum=)
        return unless finite_numeric?(last_val)

        target.maximum = last_val if target.respond_to?(:maximum=)
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
          nil
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

      def descending?(first_val, last_val)
        first_val.is_a?(Numeric) && last_val.is_a?(Numeric) && first_val > last_val
      end
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

        schema.minimum = first_val if first_val.is_a?(Numeric) && first_val.finite? && schema.respond_to?(:minimum=)
        schema.maximum = last_val if last_val.is_a?(Numeric) && last_val.finite? && schema.respond_to?(:maximum=)
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
