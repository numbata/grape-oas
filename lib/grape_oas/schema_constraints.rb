# frozen_string_literal: true

module GrapeOAS
  # Applies numeric and string constraints from documentation to a schema.
  module SchemaConstraints
    KEYS = %i[minimum maximum min_length max_length pattern].freeze

    def self.apply(schema, doc)
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
