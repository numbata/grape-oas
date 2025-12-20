# frozen_string_literal: true

require_relative "ast_walker"
require_relative "constraint_extractor"
require_relative "constraint_merger"

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Builds path-aware constraint and required field indexes from dry-schema AST
      class RuleIndex
        def initialize(contract_schema)
          @walker = AstWalker.new(ConstraintExtractor::ConstraintSet)
          @merger = ConstraintMerger
          @constraints_by_path = {}
          @required_by_object_path = Hash.new { |h, k| h[k] = {} }

          build_indexes(contract_schema)
        end

        def self.build(contract_schema)
          new(contract_schema).to_a
        end

        def to_a
          [@constraints_by_path, @required_by_object_path.transform_values(&:keys)]
        end

        private

        def build_indexes(contract_schema)
          rules = contract_schema.respond_to?(:rules) ? contract_schema.rules : {}
          rules.each_value do |rule|
            ast = rule.respond_to?(:to_ast) ? rule.to_ast : rule
            collect_constraints(ast, [])
            collect_required(ast, [], in_implication_condition: false)
          end
        end

        def collect_constraints(ast, path)
          return unless ast.is_a?(Array)

          case ast[0]
          when :key
            key_name, value_ast = parse_key_node(ast)
            return unless key_name && value_ast.is_a?(Array)

            new_path = path + [key_name]
            apply_node_constraints(value_ast, new_path)
            collect_constraints(value_ast, new_path)

          when :each
            child = ast[1]
            return unless child.is_a?(Array)

            item_path = path + ["[]"]

            # Index constraints that apply to the item schema itself
            apply_node_constraints(child, item_path)

            # Recurse so nested keys inside the item get their own paths
            collect_constraints(child, item_path)
          else
            ast.each { |child| collect_constraints(child, path) if child.is_a?(Array) }
          end
        end

        def collect_required(ast, object_path, in_implication_condition:)
          return unless ast.is_a?(Array)

          case ast[0]
          when :implication
            left, right = ast[1].is_a?(Array) ? ast[1] : [nil, nil]
            collect_required(left, object_path, in_implication_condition: true) if left
            collect_required(right, object_path, in_implication_condition: false) if right

          when :predicate
            mark_required_if_key_predicate(ast[1], object_path) unless in_implication_condition

          when :key, :each
            if ast[0] == :key
              key_name, value_ast = parse_key_node(ast)
              if key_name && value_ast.is_a?(Array)
                collect_required(value_ast, object_path + [key_name],
                                 in_implication_condition: in_implication_condition,)
              end
            elsif ast[1] # :each
              collect_required(ast[1], object_path + ["[]"],
                               in_implication_condition: in_implication_condition,)
            end

          else
            ast.each do |child|
              collect_required(child, object_path, in_implication_condition: in_implication_condition) if child.is_a?(Array)
            end
          end
        end

        def parse_key_node(ast)
          info = ast[1]
          return [nil, nil] unless info.is_a?(Array) && info.any?

          key_name = info[0]
          value_ast = info[1] || info[-1]
          [key_name&.to_s, value_ast]
        end

        def apply_node_constraints(value_ast, path)
          pruned = prune_nested_validations(value_ast)
          return unless pruned

          constraints = @walker.walk(pruned)
          constraints.required = nil if constraints.respond_to?(:required=)

          path_key = path.join("/")
          if @constraints_by_path.key?(path_key)
            @merger.merge(@constraints_by_path[path_key], constraints)
          else
            @constraints_by_path[path_key] = constraints
          end
        end

        def prune_nested_validations(ast)
          return ast unless ast.is_a?(Array)

          tag = ast[0]
          return ast unless tag.is_a?(Symbol)

          case tag
          when :each, :key
            nil

          when :set
            children, wrapped = extract_children(ast)
            pruned = children.filter_map { |c| c.is_a?(Array) ? prune_nested_validations(c) : c }
            return nil if pruned.empty?

            # rewrite set -> and, preserve wrapper style
            wrapped ? [:and, pruned] : [:and, *pruned]

          when :and, :or, :rule
            children, wrapped = extract_children(ast)
            pruned = children.filter_map { |c| c.is_a?(Array) ? prune_nested_validations(c) : c }
            return nil if pruned.empty?

            wrapped ? [tag, pruned] : [tag, *pruned]

          when :implication
            pair = ast[1]
            return ast unless pair.is_a?(Array) && pair.size >= 2

            left  = pair[0].is_a?(Array) ? prune_nested_validations(pair[0]) : pair[0]
            right = pair[1].is_a?(Array) ? prune_nested_validations(pair[1]) : pair[1]
            [:implication, [left, right]]

          when :not
            child = ast[1]
            child = prune_nested_validations(child) if child.is_a?(Array)
            [:not, child]

          else
            ast
          end
        end

        def extract_children(ast)
          # handles both shapes:
          #   [:and, [node1, node2]]
          #   [:and, node1, node2]
          payload = ast[1]

          if payload.is_a?(Array) && !payload.empty? && payload.all? { |x| x.is_a?(Array) && x[0].is_a?(Symbol) }
            [payload, true]   # wrapped list
          else
            [ast[1..], false] # splatted
          end
        end

        def mark_required_if_key_predicate(pred, object_path)
          return unless pred.is_a?(Array) && pred[0] == :key?

          name = extract_key_name(pred)
          @required_by_object_path[object_path.join("/")][name] = true if name
        end

        def extract_key_name(pred_node)
          args = pred_node[1]
          return nil unless args.is_a?(Array)

          name_pair = args.find { |x| x.is_a?(Array) && x[0] == :name }
          name_pair&.dig(1)&.to_s
        end
      end
    end
  end
end
