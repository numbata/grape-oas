# frozen_string_literal: true

module GrapeOAS
  # Normalizes values from Grape parameter or entity documentation into
  # Array, Range, or nil for OpenAPI schema generation.
  module ValuesNormalizer
    # @param values [Object] raw values from spec or documentation
    # @param context [String] description for warning messages
    # @return [Array, Range, nil]
    def self.normalize(values, context: "values")
      return nil unless values

      values = values[:value] if values.is_a?(Hash) && values.key?(:value)

      if values.respond_to?(:call)
        return nil unless values.respond_to?(:arity) && values.arity.zero?

        begin
          values = values.call
        rescue StandardError => e
          GrapeOAS.logger.warn("Proc evaluation failed for #{context} (#{e.class}): #{e.message}")
          return nil
        end
        # Optional-arg validators (proc { |v = nil| ... }) report arity 0 but return non-enum
        return nil unless values.is_a?(Array) || values.is_a?(Range) || set_instance?(values)
      end

      values = values.to_a if set_instance?(values)
      return nil unless values.is_a?(Array) || values.is_a?(Range)

      values
    end

    def self.set_instance?(value)
      defined?(Set) && value.is_a?(Set)
    end
    private_class_method :set_instance?
  end
end
