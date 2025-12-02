# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Extracts constraint information from Dry::Schema AST nodes.
      # Delegates AST walking to AstWalker and merging to ConstraintMerger.
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
          @ast_walker = AstWalker.new(ConstraintSet)
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

        attr_reader :contract, :ast_walker

        def extract_from_rules(constraints)
          return unless contract.respond_to?(:rules)

          contract.rules.each do |name, rule|
            ast = rule.respond_to?(:to_ast) ? rule.to_ast : rule
            c = walk_ast(ast)
            # infer requiredness: required rules are usually :and, optional via :implication
            c.required = ast[0] != :implication if ast.is_a?(Array)
            ConstraintMerger.merge(constraints[name], c)
          end
        end

        def extract_from_types(constraints)
          return unless contract.respond_to?(:types)

          contract.types.each do |name, dry_type|
            next unless dry_type.respond_to?(:rule_ast) || (dry_type.respond_to?(:meta) && dry_type.meta[:rules])

            asts = dry_type.respond_to?(:rule_ast) ? dry_type.rule_ast : dry_type.meta[:rules]
            Array(asts).each do |ast|
              ConstraintMerger.merge(constraints[name], walk_ast(ast))
            end
          end
        end

        def walk_ast(ast)
          ast_walker.walk(ast)
        end
      end
    end
  end
end
