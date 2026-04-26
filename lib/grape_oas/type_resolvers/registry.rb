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

      # Builds a schema using the first resolver that returns non-nil.
      # Falls back to DefaultResolver when no registered resolver produces
      # a schema, guaranteeing a non-nil return.
      #
      # @param type [String, Class, Object] The type to build schema for
      # @return [ApiModel::Schema] The built schema
      def build_schema(type)
        @resolvers.each do |resolver|
          next unless resolver.handles?(type)

          schema = resolver.build_schema(type)
          return schema if schema
        end

        DefaultResolver.build_schema(type)
      end

      # Checks if any registered resolver produces a schema for this type.
      # Does not account for the built-in DefaultResolver fallback, so
      # returning false does not mean build_schema will return nil — it
      # will still produce a string schema via DefaultResolver.
      #
      # @param type [String, Class, Object] The type to check
      # @return [Boolean]
      def registered_resolver_for?(type)
        !find(type).nil?
      end

      # Backward-compatible alias for {#registered_resolver_for?}.
      def handles?(type)
        registered_resolver_for?(type)
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

      def find(type)
        @resolvers.find { |resolver| resolver.handles?(type) }
      end

      def validate_resolver!(resolver)
        if resolver == DefaultResolver
          raise ArgumentError,
                "DefaultResolver is the built-in fallback and must not be registered in the chain"
        end

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
