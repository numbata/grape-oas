# frozen_string_literal: true

module GrapeOAS
  # Normalizes documentation hash keys so callers can use symbol access
  # uniformly. String keys that look like OpenAPI extensions ("x-*") are
  # kept as strings; all other keys are converted to symbols.
  module DocKeyNormalizer
    # @param doc [Hash] raw documentation hash from an entity exposure
    # @return [Hash] a new hash with normalized keys
    def self.normalize(doc)
      return doc if doc.empty?

      doc.transform_keys { |k| k.to_s.start_with?("x-") ? k.to_s : k.to_sym }
    end
  end
end
