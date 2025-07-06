# frozen_string_literal: true

module GrapeOAS
  module Exporter
    # Factory method to return the appropriate exporter class based on the schema type.
    # @param schema_type [Symbol] The type of schema (:oas3 or :oas2).
    # @return [Class] The exporter class for the specified schema type.
    def for(schema_type)
      case schema_type
      when :oas2
        GrapeOAS::Exporter::OAS2Schema
      when :oas3
        GrapeOAS::Exporter::OAS3Schema
      else
        raise ArgumentError, "Unsupported schema type: #{schema_type}"
      end
    end
    module_function :for
  end
end
