# frozen_string_literal: true

module GrapeOAS
  # Applies numeric and string constraints from documentation to a schema.
  module SchemaConstraints
    def self.apply(schema, doc)
      if present?(doc, :minimum)
        schema.minimum = fetch(doc, :minimum) if schema.respond_to?(:minimum=)
        schema.exclusive_minimum = nil if schema.respond_to?(:exclusive_minimum=)
      end
      if present?(doc, :maximum)
        schema.maximum = fetch(doc, :maximum) if schema.respond_to?(:maximum=)
        schema.exclusive_maximum = nil if schema.respond_to?(:exclusive_maximum=)
      end
      set_if_present(schema, :min_length=, doc, :min_length)
      set_if_present(schema, :max_length=, doc, :max_length)
      set_if_present(schema, :pattern=, doc, :pattern)
    end

    def self.present?(doc, key)
      doc.key?(key) || doc.key?(key.to_s)
    end

    def self.fetch(doc, key)
      doc.key?(key) ? doc[key] : doc[key.to_s]
    end

    def self.set_if_present(schema, setter, doc, key)
      return unless present?(doc, key) && schema.respond_to?(setter)

      schema.public_send(setter, fetch(doc, key))
    end

    private_class_method :present?, :fetch, :set_if_present
  end
end
