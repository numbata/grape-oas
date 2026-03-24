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

      return nil if values.is_a?(Hash) && !values.key?(:value)

      values = values[:value] if values.is_a?(Hash)
      return nil unless values

      if values.respond_to?(:call)
        # Two-stage defense for callable values:
        # 1) Arity check filters out validators (arity > 0) and objects without arity.
        #    This is a heuristic — optional-arg procs (proc { |v = nil| ... }) report arity 0.
        # 2) Post-call type check catches those false positives by verifying the return
        #    value is a collection type. Both guards are load-bearing; do not remove either.
        return nil unless values.respond_to?(:arity) && values.arity.zero?

        begin
          values = values.call
        rescue StandardError => e
          warn "[grape-oas] Proc evaluation failed for #{context} (#{e.class}): #{e.message}"
          return nil
        end
        return nil unless values.is_a?(Array) || values.is_a?(Range) || set_instance?(values)
      end

      values = values.to_a if set_instance?(values)
      return nil unless values.is_a?(Array) || values.is_a?(Range)
      return nil if values.is_a?(Array) && values.empty?

      values
    end

    def self.set_instance?(value)
      defined?(Set) && value.is_a?(Set)
    end
    private_class_method :set_instance?
  end
end
