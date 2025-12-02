# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Unwraps Dry::Types to extract primitives and member types.
      module TypeUnwrapper
        # Maximum depth for unwrapping nested Dry::Types (prevents infinite loops)
        MAX_DEPTH = 5

        module_function

        def derive_primitive_and_member(dry_type)
          core = unwrap(dry_type)

          return [Array, core.type.member] if array_member_type?(core)
          return [Array, core.member] if array_with_member?(core)

          primitive = core.respond_to?(:primitive) ? core.primitive : nil
          [primitive, nil]
        end

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
      end
    end
  end
end
