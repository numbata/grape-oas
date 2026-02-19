# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Unwraps Dry::Types to extract primitives and member types.
      #
      # Dry::Types can be deeply nested with wrappers (Constrained, Sum, etc.).
      # This module provides utilities to unwrap these types and extract the
      # underlying primitive type and any array member types.
      #
      # @example Unwrapping a constrained type
      #   core = TypeUnwrapper.unwrap(Dry::Types["strict.string"].constrained(max_size: 10))
      #   # => Returns the base String type
      #
      module TypeUnwrapper
        # Maximum depth for unwrapping nested Dry::Types (prevents infinite loops)
        MAX_DEPTH = 5

        module_function

        # Derives the primitive type and member type from a Dry::Types type.
        #
        # @param dry_type [Dry::Types::Type] the type to analyze
        # @return [Array(Class, Object)] tuple of [primitive_class, member_type_or_nil]
        def derive_primitive_and_member(dry_type)
          # Handle boolean Sum types (TrueClass | FalseClass)
          return [TrueClass, nil] if boolean_sum_type?(dry_type)

          # Handle nullable Sum types (NilClass | SomeType) from maybe()
          # Sum uses Composition (.left/.right), not Decorator (.type),
          # so unwrap() can't traverse it. Extract the non-nil branch instead.
          if nullable_sum_type?(dry_type)
            non_nil = dry_type.respond_to?(:right) && !nil_type?(dry_type.right) ? dry_type.right : dry_type.left
            return derive_primitive_and_member(non_nil)
          end

          core = unwrap(dry_type)

          return [Array, core.type.member] if array_member_type?(core)
          return [Array, core.member] if array_with_member?(core)

          primitive = core.respond_to?(:primitive) ? core.primitive : nil
          [primitive, nil]
        end

        # Unwraps a Dry::Types type to get to the core type.
        #
        # @param dry_type [Dry::Types::Type] the type to unwrap
        # @return [Dry::Types::Type] the unwrapped core type
        def unwrap(dry_type)
          current = dry_type
          depth = 0

          while current.respond_to?(:type) && depth < MAX_DEPTH
            inner = current.type
            break if inner.equal?(current)

            current = inner
            depth += 1
          end

          current
        end

        # Detects if type is a meaningful Dry::Types::Sum (union type like TypeA | TypeB).
        #
        # Returns false for nullable sums (nil | String) which are created by maybe(),
        # as those should be treated as nullable types rather than union types.
        #
        # @param dry_type [Dry::Types::Type] the type to check
        # @return [Boolean] true if it's a meaningful sum type
        def sum_type?(dry_type)
          return false unless defined?(Dry::Types::Sum)
          return false unless dry_type.is_a?(Dry::Types::Sum) || dry_type.class.name&.include?("Sum")

          # Check if this is a "schema sum" (both sides are Hash schemas)
          # vs a "nullable sum" (one side is NilClass from maybe())
          schema_sum?(dry_type)
        end

        # Checks if Sum type represents a union of schemas (not just nullable).
        #
        # @param sum_type [Dry::Types::Sum] the sum type to check
        # @return [Boolean] true if it's a union of 2+ non-nil schemas
        def schema_sum?(sum_type)
          return false unless sum_type.respond_to?(:left) && sum_type.respond_to?(:right)

          types = extract_sum_types(sum_type)

          # Filter out NilClass types (from maybe())
          non_nil_types = types.reject { |t| nil_type?(t) }

          # It's a schema sum if we have 2+ non-nil types and at least one is a Hash schema
          non_nil_types.length >= 2 && non_nil_types.any? { |t| hash_schema?(t) }
        end

        # Checks if type is a nil type (from maybe()).
        #
        # @param dry_type [Dry::Types::Type] the type to check
        # @return [Boolean] true if it's a NilClass type
        def nil_type?(dry_type)
          return true if dry_type.respond_to?(:primitive) && dry_type.primitive == NilClass

          # Check wrapped type
          unwrapped = unwrap(dry_type)
          unwrapped.respond_to?(:primitive) && unwrapped.primitive == NilClass
        end

        # Checks if type is a Hash schema (has keys defined).
        #
        # @param dry_type [Dry::Types::Type] the type to check
        # @return [Boolean] true if it's a Hash schema with keys
        def hash_schema?(dry_type)
          return true if dry_type.respond_to?(:keys) && dry_type.keys.any?

          unwrapped = unwrap(dry_type)
          unwrapped.respond_to?(:keys) && unwrapped.keys.any?
        end

        # Recursively extracts all types from a Sum type tree.
        #
        # A | B | C becomes Sum(Sum(A, B), C), so we need to traverse the tree.
        #
        # @param dry_type [Dry::Types::Type] the sum type to extract from
        # @param types [Array] accumulator array for types (internal use)
        # @return [Array<Dry::Types::Type>] all leaf types in the sum
        def extract_sum_types(dry_type, types = [])
          if dry_type.respond_to?(:left) && dry_type.respond_to?(:right)
            extract_sum_types(dry_type.left, types)
            extract_sum_types(dry_type.right, types)
          else
            types << dry_type
          end
          types
        end

        def array_member_type?(core)
          defined?(Dry::Types::Array::Member) &&
            core.respond_to?(:type) &&
            core.type.is_a?(Dry::Types::Array::Member)
        end
        private_class_method :array_member_type?

        def array_with_member?(core)
          core.respond_to?(:member) &&
            core.respond_to?(:primitive) &&
            core.primitive == Array
        end
        private_class_method :array_with_member?

        def nullable_sum_type?(dry_type)
          return false unless dry_type.respond_to?(:left) && dry_type.respond_to?(:right)

          nil_type?(dry_type.left) || nil_type?(dry_type.right)
        end
        private_class_method :nullable_sum_type?

        def boolean_sum_type?(dry_type)
          return false unless dry_type.respond_to?(:left) && dry_type.respond_to?(:right)

          boolean_type?(dry_type.left) && boolean_type?(dry_type.right)
        end
        private_class_method :boolean_sum_type?

        def boolean_type?(dry_type)
          return false unless dry_type

          return [TrueClass, FalseClass].include?(dry_type.primitive) if dry_type.respond_to?(:primitive)

          false
        end
        private_class_method :boolean_type?
      end
    end
  end
end
