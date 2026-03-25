# frozen_string_literal: true

module GrapeOAS
  # Applies numeric and string constraints from documentation to a schema.
  #
  # Callers are responsible for passing a symbol-keyed doc hash (produced by
  # normalize_doc_keys or equivalent). The internal transform_keys call is kept
  # as a defensive fallback so that direct callers (e.g. in tests) passing raw
  # string-keyed hashes continue to work.
  module SchemaConstraints
    def self.apply(schema, doc)
      doc = doc.transform_keys(&:to_sym) unless doc.empty?
      if doc.key?(:minimum)
        schema.minimum = doc[:minimum] if schema.respond_to?(:minimum=)
        # Clear stale exclusive_minimum; re-set below if also provided
        schema.exclusive_minimum = nil if schema.respond_to?(:exclusive_minimum=) && !doc.key?(:exclusive_minimum)
      end
      if doc.key?(:maximum)
        schema.maximum = doc[:maximum] if schema.respond_to?(:maximum=)
        # Clear stale exclusive_maximum; re-set below if also provided
        schema.exclusive_maximum = nil if schema.respond_to?(:exclusive_maximum=) && !doc.key?(:exclusive_maximum)
      end
      set_if_present(schema, :exclusive_minimum=, doc, :exclusive_minimum)
      set_if_present(schema, :exclusive_maximum=, doc, :exclusive_maximum)
      set_if_present(schema, :min_length=, doc, :min_length)
      set_if_present(schema, :max_length=, doc, :max_length)
      set_if_present(schema, :pattern=, doc, :pattern)
    end

    def self.set_if_present(schema, setter, doc, key)
      return unless doc.key?(key) && schema.respond_to?(setter)

      schema.public_send(setter, doc[key])
    end

    private_class_method :set_if_present
  end
end
