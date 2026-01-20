# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Handles Dry::Schema predicate nodes and updates constraints accordingly.
      class PredicateHandler
        def initialize(constraints)
          @constraints = constraints
        end

        HANDLED_PREDICATES = %i[
          key? size? min_size? max_size? range? empty? bytesize? max_bytesize? min_bytesize?
          maybe nil? filled?
          included_in? excluded_from? eql? true? false?
          gt? gteq? min? lt? lteq? max? multiple_of? divisible_by?
          format? uuid? uri? url? email? date? time? date_time?
          str? int? array? hash? number? float? bool? boolean? type?
          odd? even?
        ].freeze

        def handle(pred_node)
          return unless pred_node.is_a?(Array)

          name = pred_node[0]
          args = Array(pred_node[1])

          dispatch_predicate(name, args)
          constraints.unhandled_predicates << name unless HANDLED_PREDICATES.include?(name)
        end

        private

        attr_reader :constraints

        def dispatch_predicate(name, args)
          case name
          when :key? then constraints.required = true if constraints.required.nil?
          when :size?, :min_size? then handle_size(name, args)
          when :max_size? then constraints.max_size = ArgumentExtractor.extract_numeric(args.first)
          when :range? then handle_range(args)
          when :empty? then constraints.min_size = constraints.max_size = 0
          when :bytesize?, :max_bytesize?, :min_bytesize? then handle_bytesize(name, args)
          when :maybe, :nil? then constraints.nullable = true
          when :filled? then constraints.nullable = false
          when :included_in? then apply_enum_from_list(args)
          when :excluded_from? then apply_excluded_from_list(args)
          when :eql? then apply_enum_from_literal(args)
          when :true? then constraints.enum = [true]
          when :false? then constraints.enum = [false]
          when :gt? then apply_exclusive_minimum(args)
          when :gteq?, :min? then constraints.minimum = ArgumentExtractor.extract_numeric(args.first)
          when :lt? then apply_exclusive_maximum(args)
          when :lteq?, :max? then constraints.maximum = ArgumentExtractor.extract_numeric(args.first)
          when :multiple_of?, :divisible_by? then handle_multiple_of(args)
          when :format? then apply_pattern(args)
          when :uuid? then constraints.format = "uuid"
          when :uri?, :url? then constraints.format = "uri"
          when :email? then constraints.format = "email"
          when :date? then constraints.format = "date"
          when :time?, :date_time? then constraints.format = "date-time"
          when :type? then constraints.type_predicate = ArgumentExtractor.extract_literal(args.first)
          when :odd? then constraints.parity = :odd
          when :even? then constraints.parity = :even
          end
        end

        def apply_enum_from_list(args)
          vals = ArgumentExtractor.extract_list(args.first)
          if vals
            constraints.enum = vals
          else
            # For numeric ranges, extract min/max instead of enum
            apply_min_max_from_range(args)
          end
        end

        def apply_min_max_from_range(args)
          rng = ArgumentExtractor.extract_range(args.first)
          apply_range_constraints(rng)
        end

        def apply_range_constraints(rng)
          return unless rng

          constraints.minimum = rng.begin if rng.begin
          constraints.maximum = rng.end if rng.end
          constraints.exclusive_maximum = rng.exclude_end? if rng.end
        end

        def apply_excluded_from_list(args)
          vals = ArgumentExtractor.extract_list(args.first)
          constraints.excluded_values = vals if vals
        end

        def apply_enum_from_literal(args)
          val = ArgumentExtractor.extract_literal(args.first)
          constraints.enum = [val] unless val.nil?
        end

        def apply_exclusive_minimum(args)
          constraints.minimum = ArgumentExtractor.extract_numeric(args.first)
          constraints.exclusive_minimum = true if constraints.minimum
        end

        def apply_exclusive_maximum(args)
          constraints.maximum = ArgumentExtractor.extract_numeric(args.first)
          constraints.exclusive_maximum = true if constraints.maximum
        end

        def apply_pattern(args)
          pat = ArgumentExtractor.extract_pattern(args.first)
          constraints.pattern = pat if pat
        end

        def handle_size(name, args)
          rng = ArgumentExtractor.extract_range(args.first)

          if rng
            constraints.min_size = rng.begin if rng.begin
            constraints.max_size = rng.max if rng.end
          else
            min_val = ArgumentExtractor.extract_numeric(args[0])
            max_val = ArgumentExtractor.extract_numeric(args[1]) if name == :size?
            constraints.min_size = min_val if min_val
            constraints.max_size = max_val if max_val
          end
        end

        def handle_range(args)
          rng = ArgumentExtractor.extract_range(args.first)
          apply_range_constraints(rng)
        end

        def handle_multiple_of(args)
          val = ArgumentExtractor.extract_numeric(args.first)
          constraints.extensions ||= {}
          constraints.extensions["multipleOf"] ||= val if val
        end

        def handle_bytesize(name, args)
          min_val = ArgumentExtractor.extract_numeric(args[0]) if %i[bytesize? min_bytesize?].include?(name)
          max_source = name == :bytesize? ? args[1] : args[0]
          max_val = ArgumentExtractor.extract_numeric(max_source) if %i[bytesize? max_bytesize?].include?(name)
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        end
      end
    end
  end
end
