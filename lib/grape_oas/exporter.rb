# frozen_string_literal: true

module GrapeOAS
  module Exporter
    # Returns the exporter class for the given schema type.
    # Delegates to the global exporter registry.
    #
    # @param schema_type [Symbol] The type of schema (:oas2, :oas3, :oas30, :oas31)
    # @return [Class] The exporter class for the specified schema type
    # @raise [ArgumentError] if no exporter is registered for the type
    def for(schema_type)
      GrapeOAS.exporters.for(schema_type)
    end
    module_function :for
  end
end
