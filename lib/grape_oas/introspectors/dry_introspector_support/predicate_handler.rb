# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Handles Dry::Schema predicate nodes and updates constraints accordingly.
      class PredicateHandler
        def initialize(constraints)
          @constraints = constraints
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def handle(pred_node)
          return unless pred_node.is_a?(Array)

          name = pred_node[0]
          args = Array(pred_node[1])

          case name
          when :key?
            constraints.required = true if constraints.required.nil?
          when :size?, :min_size?
            handle_size(name, args)
          when :max_size?
            val = ArgumentExtractor.extract_numeric(args.first)
            constraints.max_size = val if val
          when :range?
            handle_range(args)
          when :maybe, :nil?
            constraints.nullable = true
          when :filled?
            constraints.nullable = false
          when :empty?
            constraints.min_size = 0
            constraints.max_size = 0
          when :included_in?
            vals = ArgumentExtractor.extract_list(args.first)
            constraints.enum = vals if vals
          when :excluded_from?
            vals = ArgumentExtractor.extract_list(args.first)
            constraints.excluded_values = vals if vals
          when :eql?
            val = ArgumentExtractor.extract_literal(args.first)
            constraints.enum = [val] unless val.nil?
          when :gt?
            constraints.minimum = ArgumentExtractor.extract_numeric(args.first)
            constraints.exclusive_minimum = true if constraints.minimum
          when :gteq?, :min?
            constraints.minimum = ArgumentExtractor.extract_numeric(args.first)
          when :lt?
            constraints.maximum = ArgumentExtractor.extract_numeric(args.first)
            constraints.exclusive_maximum = true if constraints.maximum
          when :lteq?, :max?
            constraints.maximum = ArgumentExtractor.extract_numeric(args.first)
          when :format?
            pat = ArgumentExtractor.extract_pattern(args.first)
            constraints.pattern = pat if pat
          when :uuid?
            constraints.format = "uuid"
          when :uri?, :url?
            constraints.format = "uri"
          when :email?
            constraints.format = "email"
          when :str?, :int?, :array?, :hash?, :number?, :float?
            # already represented by type inference
          when :date?
            constraints.format = "date"
          when :time?, :date_time?
            constraints.format = "date-time"
          when :bool?, :boolean?
            constraints.type_predicate ||= :boolean
          when :type?
            constraints.type_predicate = ArgumentExtractor.extract_literal(args.first)
          when :odd?
            constraints.parity = :odd
          when :even?
            constraints.parity = :even
          when :multiple_of?, :divisible_by?
            handle_multiple_of(args)
          when :bytesize?, :max_bytesize?, :min_bytesize?
            handle_bytesize(name, args)
          when :true?
            constraints.enum = [true]
          when :false?
            constraints.enum = [false]
          else
            constraints.unhandled_predicates << name
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        private

        attr_reader :constraints

        def handle_size(name, args)
          min_val = ArgumentExtractor.extract_numeric(args[0])
          max_val = ArgumentExtractor.extract_numeric(args[1]) if name == :size?
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        end

        def handle_range(args)
          rng = args.first.is_a?(Range) ? args.first : ArgumentExtractor.extract_range(args.first)
          return unless rng

          constraints.minimum = rng.begin if rng.begin
          constraints.maximum = rng.end if rng.end
          constraints.exclusive_maximum = rng.exclude_end?
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
