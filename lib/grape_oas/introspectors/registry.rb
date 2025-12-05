# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    # Registry for managing introspectors that can build schemas from various sources.
    # Allows third-party gems to register custom introspectors for new schema formats.
    #
    # @example Registering a custom introspector
    #   GrapeOAS.introspectors.register(MyCustomIntrospector)
    #
    # @example Inserting before an existing introspector
    #   GrapeOAS.introspectors.register(HighPriorityIntrospector, before: EntityIntrospector)
    #
    class Registry
      include Enumerable

      def initialize
        @introspectors = []
      end

      # Registers an introspector class.
      #
      # @param introspector [Class] Class that extends GrapeOAS::Introspectors::Base
      # @param before [Class, nil] Insert before this introspector
      # @param after [Class, nil] Insert after this introspector
      # @return [self]
      def register(introspector, before: nil, after: nil)
        validate_introspector!(introspector)

        if before
          insert_before(introspector, before)
        elsif after
          insert_after(introspector, after)
        else
          @introspectors << introspector unless @introspectors.include?(introspector)
        end

        self
      end

      # Unregisters an introspector class.
      #
      # @param introspector [Class] The introspector to remove
      # @return [self]
      def unregister(introspector)
        @introspectors.delete(introspector)
        self
      end

      # Finds the first introspector that can handle the given subject.
      #
      # @param subject [Object] The object to introspect
      # @return [Class, nil] The introspector class, or nil if none found
      def find(subject)
        @introspectors.find { |introspector| introspector.handles?(subject) }
      end

      # Builds a schema using the appropriate introspector.
      #
      # @param subject [Object] The object to introspect
      # @param stack [Array] Recursion stack for cycle detection
      # @param registry [Hash] Schema registry for caching
      # @return [ApiModel::Schema, nil] The built schema, or nil if no handler found
      def build_schema(subject, stack: [], registry: {})
        introspector = find(subject)
        return nil unless introspector

        introspector.build_schema(subject, stack: stack, registry: registry)
      end

      # Checks if any introspector can handle the given subject.
      #
      # @param subject [Object] The object to check
      # @return [Boolean]
      def handles?(subject)
        @introspectors.any? { |introspector| introspector.handles?(subject) }
      end

      # Iterates over all registered introspectors.
      #
      # @yield [introspector] Each registered introspector
      def each(&)
        @introspectors.each(&)
      end

      # Returns the number of registered introspectors.
      #
      # @return [Integer]
      def size
        @introspectors.size
      end

      # Clears all registered introspectors.
      #
      # @return [self]
      def clear
        @introspectors.clear
        self
      end

      # Returns a list of registered introspectors.
      #
      # @return [Array<Class>]
      def to_a
        @introspectors.dup
      end

      private

      def validate_introspector!(introspector)
        return if introspector.respond_to?(:handles?) && introspector.respond_to?(:build_schema)

        raise ArgumentError,
              "Introspector must respond to .handles?(subject) and .build_schema(subject, stack:, registry:)"
      end

      def insert_before(introspector, target)
        index = @introspectors.index(target)
        if index
          @introspectors.insert(index, introspector) unless @introspectors.include?(introspector)
        else
          @introspectors << introspector unless @introspectors.include?(introspector)
        end
      end

      def insert_after(introspector, target)
        index = @introspectors.index(target)
        if index
          @introspectors.insert(index + 1, introspector) unless @introspectors.include?(introspector)
        else
          @introspectors << introspector unless @introspectors.include?(introspector)
        end
      end
    end
  end
end
