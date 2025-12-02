# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Merges constraint sets, combining values from source into target.
      module ConstraintMerger
        module_function

        def merge(target, source)
          return unless source

          merge_basic_constraints(target, source)
          merge_bound_constraints(target, source)
          merge_extension_constraints(target, source)
        end

        def merge_basic_constraints(target, source)
          target.enum ||= source.enum
          target.nullable ||= source.nullable
          target.pattern ||= source.pattern if source.pattern
          target.format ||= source.format if source.format
          target.required = source.required unless source.required.nil?
          target.type_predicate ||= source.type_predicate if source.type_predicate
          target.parity ||= source.parity if source.parity
        end
        private_class_method :merge_basic_constraints

        def merge_bound_constraints(target, source)
          target.min_size ||= source.min_size if source.min_size
          target.max_size ||= source.max_size if source.max_size
          target.minimum ||= source.minimum if source.minimum
          target.maximum ||= source.maximum if source.maximum
          target.exclusive_minimum ||= source.exclusive_minimum
          target.exclusive_maximum ||= source.exclusive_maximum
        end
        private_class_method :merge_bound_constraints

        def merge_extension_constraints(target, source)
          target.excluded_values ||= source.excluded_values if source.excluded_values
          target.unhandled_predicates |= Array(source.unhandled_predicates) if source.unhandled_predicates
        end
        private_class_method :merge_extension_constraints
      end
    end
  end
end
