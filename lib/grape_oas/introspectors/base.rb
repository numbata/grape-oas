# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    # Base module that defines the interface for all introspectors.
    # Any introspector (built-in or third-party) must implement these class methods.
    #
    # @example Implementing a custom introspector
    #   class MyIntrospector
    #     extend GrapeOAS::Introspectors::Base
    #
    #     def self.handles?(subject)
    #       subject.is_a?(Class) && subject < MyResponseModel
    #     end
    #
    #     def self.build_schema(subject, stack: [], registry: {})
    #       # Build and return an ApiModel::Schema
    #     end
    #   end
    #
    #   # Register the introspector
    #   GrapeOAS.introspectors.register(MyIntrospector)
    #
    module Base
      # Checks if this introspector can handle the given subject.
      #
      # @param subject [Object] The object to introspect (e.g., entity class, contract)
      # @return [Boolean] true if this introspector can handle the subject
      def handles?(subject)
        raise NotImplementedError, "#{self} must implement .handles?(subject)"
      end

      # Builds a schema from the given subject.
      #
      # @param subject [Object] The object to introspect
      # @param stack [Array] Recursion stack for cycle detection
      # @param registry [Hash] Schema registry for caching built schemas
      # @return [ApiModel::Schema, nil] The built schema, or nil if not applicable
      def build_schema(subject, stack: [], registry: {})
        raise NotImplementedError, "#{self} must implement .build_schema(subject, stack:, registry:)"
      end
    end
  end
end
