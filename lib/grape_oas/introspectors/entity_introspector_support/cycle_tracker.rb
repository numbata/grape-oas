# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Tracks and handles cyclic references during entity introspection.
      class CycleTracker
        def initialize(entity_class, stack)
          @entity_class = entity_class
          @stack = stack
        end

        # Checks if the current entity class is already in the processing stack.
        #
        # @return [Boolean] true if a cycle is detected
        def cyclic_reference?
          @stack.include?(@entity_class)
        end

        # Handles a detected cycle by marking the schema with a description.
        #
        # @param schema [ApiModel::Schema] the schema to mark
        # @return [ApiModel::Schema] the marked schema
        def handle_cycle(schema)
          schema.description ||= "Cycle detected while introspecting"
          schema
        end

        # Executes a block while tracking the current entity in the stack.
        #
        # @yield the block to execute while tracking
        # @return the result of the block
        def with_tracking
          @stack << @entity_class
          yield
        ensure
          @stack.pop
        end
      end
    end
  end
end
