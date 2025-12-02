# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Walks Dry::Schema AST nodes and extracts constraints.
      class AstWalker
        LOGIC_TAGS = %i[predicate rule and or implication not key each].freeze

        def initialize(constraint_set_class)
          @constraint_set_class = constraint_set_class
        end

        def walk(ast)
          constraints = constraint_set_class.new(unhandled_predicates: [])
          visit(ast, constraints)
          constraints
        end

        def intersect_branches(branches)
          return branches.first if branches.size <= 1

          base = branches.first
          branches[1..].each do |b|
            intersect_branch(base, b)
          end
          base
        end

        private

        attr_reader :constraint_set_class

        def visit(node, constraints)
          return unless node.is_a?(Array)

          tag = node[0]
          if shorthand_predicate?(tag, node)
            PredicateHandler.new(constraints).handle([tag, node[1]])
            return
          end
          visit_tag(tag, node, constraints)
        end

        def shorthand_predicate?(tag, node)
          tag.is_a?(Symbol) && !LOGIC_TAGS.include?(tag) && node.length == 2
        end

        def visit_tag(tag, node, constraints)
          case tag
          when :predicate
            PredicateHandler.new(constraints).handle(node[1])
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
          branches = Array(node[1]).map { |child| branch_constraints(child) }
          common = intersect_branches(branches)
          ConstraintMerger.merge(constraints, common)
        end

        def branch_constraints(child)
          c = constraint_set_class.new(unhandled_predicates: [])
          visit(child, c)
          c
        end

        def intersect_branch(base, other)
          base.enum = (base.enum & other.enum) if base.enum && other.enum
          base.min_size = intersect_min(base.min_size, other.min_size)
          base.max_size = intersect_max(base.max_size, other.max_size)
          base.minimum = intersect_min(base.minimum, other.minimum)
          base.maximum = intersect_max(base.maximum, other.maximum)
          base.exclusive_minimum &&= other.exclusive_minimum if other.exclusive_minimum == false
          base.exclusive_maximum &&= other.exclusive_maximum if other.exclusive_maximum == false
          base.nullable &&= other.nullable if other.nullable == false
        end

        def intersect_min(val1, val2)
          val1 && val2 ? [val1, val2].max : nil
        end

        def intersect_max(val1, val2)
          val1 && val2 ? [val1, val2].min : nil
        end
      end
    end
  end
end
