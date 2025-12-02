# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DrySupport
      # Extracts constraint information from Dry::Schema AST nodes.
      # Handles predicate parsing and constraint merging for schema generation.
      class ConstraintExtractor
        # Value object holding all possible constraints extracted from a Dry contract.
        ConstraintSet = Struct.new(
          :enum,
          :nullable,
          :min_size,
          :max_size,
          :minimum,
          :maximum,
          :exclusive_minimum,
          :exclusive_maximum,
          :pattern,
          :excluded_values,
          :unhandled_predicates,
          :required,
          :type_predicate,
          :parity,
          :format,
          :extensions,
          keyword_init: true,
        )

        def self.extract(contract)
          new(contract).extract
        end

        def initialize(contract)
          @contract = contract
        end

        def extract
          constraints = Hash.new { |h, k| h[k] = ConstraintSet.new(unhandled_predicates: []) }

          extract_from_rules(constraints)
          extract_from_types(constraints)

          constraints
        rescue NoMethodError, TypeError
          {}
        end

        private

        attr_reader :contract

        def extract_from_rules(constraints)
          return unless contract.respond_to?(:rules)

          contract.rules.each do |name, rule|
            ast = rule.respond_to?(:to_ast) ? rule.to_ast : rule
            c = walk_ast(ast)
            # infer requiredness: required rules are usually :and, optional via :implication
            c.required = ast[0] != :implication if ast.is_a?(Array)
            merge_constraints(constraints[name], c)
          end
        end

        def extract_from_types(constraints)
          return unless contract.respond_to?(:types)

          contract.types.each do |name, dry_type|
            next unless dry_type.respond_to?(:rule_ast) || (dry_type.respond_to?(:meta) && dry_type.meta[:rules])

            asts = dry_type.respond_to?(:rule_ast) ? dry_type.rule_ast : dry_type.meta[:rules]
            Array(asts).each do |ast|
              merge_constraints(constraints[name], walk_ast(ast))
            end
          end
        end

        def merge_constraints(target, incoming)
          return unless incoming

          target.enum ||= incoming.enum
          target.nullable ||= incoming.nullable
          target.min_size ||= incoming.min_size if incoming.min_size
          target.max_size ||= incoming.max_size if incoming.max_size
          target.minimum ||= incoming.minimum if incoming.minimum
          target.maximum ||= incoming.maximum if incoming.maximum
          target.exclusive_minimum ||= incoming.exclusive_minimum
          target.exclusive_maximum ||= incoming.exclusive_maximum
          target.pattern ||= incoming.pattern if incoming.pattern
          target.excluded_values ||= incoming.excluded_values if incoming.excluded_values
          target.unhandled_predicates |= Array(incoming.unhandled_predicates) if incoming.unhandled_predicates
          target.required = incoming.required unless incoming.required.nil?
          target.type_predicate ||= incoming.type_predicate if incoming.type_predicate
          target.parity ||= incoming.parity if incoming.parity
          target.format ||= incoming.format if incoming.format
        end

        # Generic AST walker that is resilient to both fake rule_asts and real Dry logic ASTs
        def walk_ast(ast)
          constraints = ConstraintSet.new(unhandled_predicates: [])
          visit(ast, constraints)
          constraints
        end

        def visit(node, constraints)
          case node
          when Array
            tag = node[0]
            logic_tags = %i[predicate rule and or implication not key each]
            if tag.is_a?(Symbol) && !logic_tags.include?(tag) && node.length == 2
              handle_predicate([tag, node[1]], constraints)
              return
            end
            visit_array_node(tag, node, constraints)
          end
        end

        def visit_array_node(tag, node, constraints)
          case tag
          when :predicate
            handle_predicate(node[1], constraints)
          when :rule, :not, :each
            visit(node[1], constraints)
          when :or
            visit_or_branch(node, constraints)
          when :key
            visit(node[1][1], constraints) if node[1].is_a?(Array)
          else # :and, :implication, and any other tags
            visit_children(node, constraints)
          end
        end

        def visit_children(node, constraints)
          Array(node[1]).each { |child| visit(child, constraints) }
        end

        def visit_or_branch(node, constraints)
          # Best-effort: collect constraints common to all branches
          branches = Array(node[1]).map { |child| branch_constraints(child) }
          common = intersect_branches(branches)
          merge_constraints(constraints, common)
        end

        def branch_constraints(child)
          c = ConstraintSet.new(unhandled_predicates: [])
          visit(child, c)
          c
        end

        def intersect_branches(branches)
          return branches.first if branches.size <= 1

          base = branches.first
          branches[1..].each do |b|
            base.enum = (base.enum & b.enum) if base.enum && b.enum
            base.min_size = base.min_size && b.min_size ? [base.min_size, b.min_size].max : nil
            base.max_size = base.max_size && b.max_size ? [base.max_size, b.max_size].min : nil
            base.minimum = base.minimum && b.minimum ? [base.minimum, b.minimum].max : nil
            base.maximum = base.maximum && b.maximum ? [base.maximum, b.maximum].min : nil
            base.exclusive_minimum &&= b.exclusive_minimum if b.exclusive_minimum == false
            base.exclusive_maximum &&= b.exclusive_maximum if b.exclusive_maximum == false
            base.nullable &&= b.nullable if b.nullable == false
          end
          base
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def handle_predicate(pred_node, constraints)
          return unless pred_node.is_a?(Array)

          name = pred_node[0]
          args = Array(pred_node[1])

          case name
          when :key?
            constraints.required = true if constraints.required.nil?
          when :size?, :min_size?
            handle_size_predicate(name, args, constraints)
          when :max_size?
            val = extract_numeric_arg(args.first)
            constraints.max_size = val if val
          when :range?
            handle_range_predicate(args, constraints)
          when :maybe, :nil?
            constraints.nullable = true
          when :filled?
            constraints.nullable = false
          when :empty?
            constraints.min_size = 0
            constraints.max_size = 0
          when :included_in?
            vals = extract_list_arg(args.first)
            constraints.enum = vals if vals
          when :excluded_from?
            vals = extract_list_arg(args.first)
            constraints.excluded_values = vals if vals
          when :eql?
            val = extract_literal_arg(args.first)
            constraints.enum = [val] unless val.nil?
          when :gt?
            constraints.minimum = extract_numeric_arg(args.first)
            constraints.exclusive_minimum = true if constraints.minimum
          when :gteq?, :min?
            constraints.minimum = extract_numeric_arg(args.first)
          when :lt?
            constraints.maximum = extract_numeric_arg(args.first)
            constraints.exclusive_maximum = true if constraints.maximum
          when :lteq?, :max?
            constraints.maximum = extract_numeric_arg(args.first)
          when :format?
            pat = extract_pattern_arg(args.first)
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
            constraints.type_predicate = extract_literal_arg(args.first)
          when :odd?
            constraints.parity = :odd
          when :even?
            constraints.parity = :even
          when :multiple_of?, :divisible_by?
            handle_multiple_of_predicate(args, constraints)
          when :bytesize?, :max_bytesize?, :min_bytesize?
            handle_bytesize_predicate(name, args, constraints)
          when :true?
            constraints.enum = [true]
          when :false?
            constraints.enum = [false]
          else
            constraints.unhandled_predicates << name
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def handle_size_predicate(name, args, constraints)
          min_val = extract_numeric_arg(args[0])
          max_val = extract_numeric_arg(args[1]) if name == :size?
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        end

        def handle_range_predicate(args, constraints)
          rng = args.first.is_a?(Range) ? args.first : extract_range_arg(args.first)
          return unless rng

          constraints.minimum = rng.begin if rng.begin
          constraints.maximum = rng.end if rng.end
          constraints.exclusive_maximum = rng.exclude_end?
        end

        def handle_multiple_of_predicate(args, constraints)
          val = extract_numeric_arg(args.first)
          constraints.extensions ||= {}
          constraints.extensions["multipleOf"] ||= val if val
        end

        def handle_bytesize_predicate(name, args, constraints)
          min_val = extract_numeric_arg(args[0]) if %i[bytesize? min_bytesize?].include?(name)
          max_source = name == :bytesize? ? args[1] : args[0]
          max_val = extract_numeric_arg(max_source) if %i[bytesize? max_bytesize?].include?(name)
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        end

        def extract_numeric_arg(arg)
          return arg if arg.is_a?(Numeric)
          return arg[1] if arg.is_a?(Array) && arg.size == 2 && arg.first == :num

          nil
        end

        def extract_range_arg(arg)
          return arg if arg.is_a?(Range)
          return arg[1] if arg.is_a?(Array) && arg.first == :range

          nil
        end

        def extract_list_arg(arg)
          return arg[1] if arg.is_a?(Array) && %i[list set].include?(arg.first)

          return arg if arg.is_a?(Array)

          nil
        end

        def extract_literal_arg(arg)
          return arg unless arg.is_a?(Array)
          return arg[1] if arg.length == 2 && %i[value val literal class left right].include?(arg.first)
          return extract_literal_arg(arg.first) if arg.first.is_a?(Array)

          arg
        end

        def extract_pattern_arg(arg)
          return arg.source if arg.is_a?(Regexp)
          return arg[1].source if arg.is_a?(Array) && arg.first == :regexp && arg[1].is_a?(Regexp)
          return arg[1] if arg.is_a?(Array) && arg.first == :regexp && arg[1].is_a?(String)
          return arg[1].source if arg.is_a?(Array) && arg.first == :regex && arg[1].is_a?(Regexp)
          return arg[1] if arg.is_a?(Array) && arg.first == :regex && arg[1].is_a?(String)

          nil
        end
      end
    end
  end
end
