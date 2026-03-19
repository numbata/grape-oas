# frozen_string_literal: true

module GrapeOAS
  # Applies numeric and string constraints from documentation to a schema.
  module SchemaConstraints
    def self.apply(schema, doc)
      schema.minimum = doc[:minimum] if doc.key?(:minimum) && schema.respond_to?(:minimum=)
      if doc.key?(:maximum) && schema.respond_to?(:maximum=)
        schema.maximum = doc[:maximum]
        # Clear range-derived exclusivity when explicit maximum overrides it
        schema.exclusive_maximum = nil if schema.respond_to?(:exclusive_maximum=)
      end
      schema.min_length = doc[:min_length] if doc.key?(:min_length) && schema.respond_to?(:min_length=)
      schema.max_length = doc[:max_length] if doc.key?(:max_length) && schema.respond_to?(:max_length=)
      schema.pattern = doc[:pattern] if doc.key?(:pattern) && schema.respond_to?(:pattern=)
    end
  end
end
