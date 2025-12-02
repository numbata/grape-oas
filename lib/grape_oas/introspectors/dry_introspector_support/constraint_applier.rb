# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Applies extracted constraints to ApiModel::Schema objects.
      class ConstraintApplier
        def initialize(schema, constraints, meta = {})
          @schema = schema
          @constraints = constraints
          @meta = meta
        end

        def apply_meta
          case schema.type
          when Constants::SchemaTypes::STRING
            apply_string_meta
          when Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER
            apply_numeric_meta
          when Constants::SchemaTypes::ARRAY
            apply_array_meta
          end
        end

        def apply_rule_constraints
          return unless constraints

          apply_type_specific_constraints
          apply_common_constraints
          apply_extension_constraints
          attach_unhandled
        end

        private

        attr_reader :schema, :constraints, :meta

        def apply_string_meta
          min_length = meta[:min_size] || meta[:min_length]
          max_length = meta[:max_size] || meta[:max_length]
          schema.min_length = min_length if min_length
          schema.max_length = max_length if max_length
          schema.pattern = meta[:pattern] if meta[:pattern]
        end

        def apply_array_meta
          min_items = meta[:min_size] || meta[:min_items]
          max_items = meta[:max_size] || meta[:max_items]
          schema.min_items = min_items if min_items
          schema.max_items = max_items if max_items
        end

        def apply_numeric_meta
          if meta[:gt]
            schema.minimum = meta[:gt]
            schema.exclusive_minimum = true
          elsif meta[:gteq]
            schema.minimum = meta[:gteq]
          end

          if meta[:lt]
            schema.maximum = meta[:lt]
            schema.exclusive_maximum = true
          elsif meta[:lteq]
            schema.maximum = meta[:lteq]
          end
        end

        def apply_type_specific_constraints
          case schema.type
          when Constants::SchemaTypes::STRING
            apply_string_constraints
          when Constants::SchemaTypes::ARRAY
            apply_array_constraints
          when Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER
            apply_numeric_constraints
          end
        end

        def apply_string_constraints
          schema.min_length ||= constraints.min_size if constraints.min_size
          schema.max_length ||= constraints.max_size if constraints.max_size
          schema.pattern ||= constraints.pattern if constraints.pattern
        end

        def apply_array_constraints
          schema.min_items ||= constraints.min_size if constraints.min_size
          schema.max_items ||= constraints.max_size if constraints.max_size
        end

        def apply_numeric_constraints
          numeric_min = constraints.minimum || constraints.min_size
          numeric_max = constraints.maximum || constraints.max_size
          schema.minimum ||= numeric_min if numeric_min
          schema.maximum ||= numeric_max if numeric_max
          schema.exclusive_minimum ||= constraints.exclusive_minimum
          schema.exclusive_maximum ||= constraints.exclusive_maximum
        end

        def apply_common_constraints
          schema.enum ||= constraints.enum if constraints.enum
          schema.nullable = true if constraints.nullable
          schema.format ||= constraints.format if constraints.format
        end

        def apply_extension_constraints
          apply_extension("multipleOf", constraints.extensions&.dig("multipleOf"))
          apply_extension("x-excludedValues", constraints.excluded_values)
          apply_extension("x-typePredicate", constraints.type_predicate)
          apply_extension("x-numberParity", constraints.parity&.to_s)
        end

        def apply_extension(key, value)
          return unless value

          schema.extensions ||= {}
          schema.extensions[key] ||= value
        end

        def attach_unhandled
          return unless constraints&.unhandled_predicates

          filtered = Array(constraints.unhandled_predicates) - ignored_predicates
          return if filtered.empty?

          schema.extensions ||= {}
          schema.extensions["x-unhandledPredicates"] = filtered
        end

        def ignored_predicates
          %i[key? key str? int? bool? boolean? array? hash? number? float?]
        end
      end
    end
  end
end
