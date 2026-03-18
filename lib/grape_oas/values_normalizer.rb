# frozen_string_literal: true

module GrapeOAS
  # Normalizes values from Grape parameter or entity documentation into
  # a form suitable for OpenAPI schema generation (Array, Range, or nil).
  # Handles Proc/Lambda evaluation, arity checking, callable validation,
  # and optional-arg validator guarding.
  module ValuesNormalizer
    # Resolves a values specification into an Array, Range, Set, or nil.
    # Evaluates arity-0 procs, skips validators (arity > 0), and guards
    # against callable objects without arity and optional-arg validators.
    #
    # @param values [Object] raw values from spec or documentation
    # @param context [String] description for warning messages (e.g. "parameter 'status'")
    # @return [Array, Range, Set, nil] normalized values or nil if not applicable
    def self.normalize(values, context: "values")
      return nil unless values

      # Handle Hash format { value: ..., message: ... } - extract the value
      values = values[:value] if values.is_a?(Hash) && values.key?(:value)

      if values.respond_to?(:call)
        return nil unless values.respond_to?(:arity) && values.arity.zero?

        begin
          values = values.call
        rescue StandardError => e
          warn "[grape-oas] Proc evaluation failed for #{context} (#{e.class}): #{e.message}"
          return nil
        end
        # Guard against optional-arg validators (proc { |v = nil| ... }) that
        # report arity 0 but return non-enum results when called without args.
        return nil unless values.is_a?(Array) || values.is_a?(Range) || (defined?(Set) && values.is_a?(Set))
      end

      values
    end
  end
end
