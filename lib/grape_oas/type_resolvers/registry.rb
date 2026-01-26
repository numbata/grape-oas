# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Registry for managing type resolvers that convert Grape's stringified types
    # back to OpenAPI schemas.
    #
    # Resolvers are checked in order until one returns true from `handles?`.
    # This allows custom resolvers to be inserted with higher priority.
    #
    # @example Registering a custom resolver
    #   GrapeOAS.type_resolvers.register(MyCustomResolver)
    #
    # @example Inserting before an existing resolver
    #   GrapeOAS.type_resolvers.register(HighPriorityResolver, before: ArrayResolver)
    #
    class Registry
      include Enumerable

      def initialize
        @resolvers = []
      end

      # Registers a type resolver class.
      #
      # @param resolver [Class] Class that extends GrapeOAS::TypeResolvers::Base
      # @param before [Class, nil] Insert before this resolver
      # @param after [Class, nil] Insert after this resolver
      # @return [self]
      def register(resolver, before: nil, after: nil)
        validate_resolver!(resolver)

        if before
          insert_before(resolver, before)
        elsif after
          insert_after(resolver, after)
        else
          @resolvers << resolver unless @resolvers.include?(resolver)
        end

        self
      end

      # Unregisters a type resolver class.
      #
      # @param resolver [Class] The resolver to remove
      # @return [self]
      def unregister(resolver)
        @resolvers.delete(resolver)
        self
      end

      # Finds the first resolver that can handle the given type.
      #
      # @param type [String, Class, Object] The type to resolve
      # @return [Class, nil] The resolver class, or nil if none found
      def find(type)
        @resolvers.find { |resolver| resolver.handles?(type) }
      end

      # Builds a schema using the appropriate resolver.
      #
      # @param type [String, Class, Object] The type to build schema for
      # @return [ApiModel::Schema, nil] The built schema, or nil if no handler found
      def build_schema(type)
        resolver = find(type)
        return nil unless resolver

        resolver.build_schema(type)
      end

      # Checks if any resolver can handle the given type.
      #
      # @param type [String, Class, Object] The type to check
      # @return [Boolean]
      def handles?(type)
        @resolvers.any? { |resolver| resolver.handles?(type) }
      end

      # Iterates over all registered resolvers.
      #
      # @yield [resolver] Each registered resolver
      def each(&)
        @resolvers.each(&)
      end

      # Returns the number of registered resolvers.
      #
      # @return [Integer]
      def size
        @resolvers.size
      end

      # Clears all registered resolvers.
      #
      # @return [self]
      def clear
        @resolvers.clear
        self
      end

      # Returns a list of registered resolvers.
      #
      # @return [Array<Class>]
      def to_a
        @resolvers.dup
      end

      private

      def validate_resolver!(resolver)
        return if resolver.respond_to?(:handles?) && resolver.respond_to?(:build_schema)

        raise ArgumentError,
              "Resolver must respond to .handles?(type) and .build_schema(type)"
      end

      def insert_before(resolver, target)
        index = @resolvers.index(target)
        if index
          @resolvers.insert(index, resolver) unless @resolvers.include?(resolver)
        else
          @resolvers << resolver unless @resolvers.include?(resolver)
        end
      end

      def insert_after(resolver, target)
        index = @resolvers.index(target)
        if index
          @resolvers.insert(index + 1, resolver) unless @resolvers.include?(resolver)
        else
          @resolvers << resolver unless @resolvers.include?(resolver)
        end
      end
    end
  end
end
