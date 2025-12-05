# frozen_string_literal: true

module GrapeOAS
  module Exporter
    # Registry for managing schema exporters for different OpenAPI versions.
    # Allows third-party gems to register custom exporters for new formats.
    #
    # @example Registering a custom exporter with single alias
    #   GrapeOAS.exporters.register(MyCustomExporter, as: :custom)
    #
    # @example Registering with multiple aliases
    #   GrapeOAS.exporters.register(OAS30Schema, as: [:oas3, :oas30])
    #
    class Registry
      def initialize
        @exporters = {}
      end

      # Registers an exporter class for one or more schema types.
      #
      # @param exporter_class [Class] The exporter class to register
      # @param as [Symbol, Array<Symbol>] The schema type identifier(s)
      # @return [self]
      def register(exporter_class, as:)
        schema_types = Array(as)
        schema_types.each { |type| @exporters[type] = exporter_class }
        self
      end

      # Unregisters an exporter for one or more schema types.
      #
      # @param schema_types [Symbol, Array<Symbol>] The schema type(s) to remove
      # @return [self]
      def unregister(*schema_types)
        schema_types.flatten.each { |type| @exporters.delete(type) }
        self
      end

      # Finds the exporter class for a given schema type.
      #
      # @param schema_type [Symbol] The schema type
      # @return [Class] The exporter class
      # @raise [ArgumentError] if no exporter is registered for the type
      def for(schema_type)
        exporter = @exporters[schema_type]
        raise ArgumentError, "Unsupported schema type: #{schema_type}" unless exporter

        exporter
      end

      # Checks if an exporter is registered for the given schema type.
      #
      # @param schema_type [Symbol] The schema type to check
      # @return [Boolean]
      def registered?(schema_type)
        @exporters.key?(schema_type)
      end

      # Returns all registered schema types.
      #
      # @return [Array<Symbol>]
      def schema_types
        @exporters.keys
      end

      # Returns the number of registered exporters.
      #
      # @return [Integer]
      def size
        @exporters.size
      end

      # Clears all registered exporters.
      #
      # @return [self]
      def clear
        @exporters.clear
        self
      end
    end
  end
end
