# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    # Extracts an ApiModel schema from a Dry::Schema contract
    class DrySchemaProcessor
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

      def self.build(contract)
        new(contract).build
      end

      def initialize(contract)
        @contract = contract
      end

      def build
        return unless contract.respond_to?(:types)

        rule_constraints = extract_rule_constraints(contract)
        schema = GrapeOAS::ApiModel::Schema.new(type: "object")

        contract.types.each do |name, dry_type|
          constraints = rule_constraints[name]
          @current_constraints = constraints
          prop_schema = build_schema_for_type(dry_type, constraints)
          schema.add_property(name, prop_schema, required: required?(dry_type))
        end
        @current_constraints = nil

        schema
      end

      private

      attr_reader :contract

      def required?(dry_type)
        # prefer rule-derived info if present
        return @current_constraints.required if @current_constraints && !@current_constraints.required.nil?

        meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
        return false if dry_type.respond_to?(:optional?) && dry_type.optional?
        return false if meta[:omittable]

        true
      end

      def build_schema_for_type(dry_type, constraints = nil)
        constraints ||= ConstraintSet.new(unhandled_predicates: [])
        meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}

        primitive, member = derive_primitive_and_member(dry_type)
        enum_vals = extract_enum_from_type(dry_type)

        schema = if primitive == Array
                   items_schema = member ? build_schema_for_type(member) : GrapeOAS::ApiModel::Schema.new(type: "string")
                   GrapeOAS::ApiModel::Schema.new(type: "array", items: items_schema)
                 elsif primitive == Hash
                   GrapeOAS::ApiModel::Schema.new(type: "object")
                 elsif primitive == Integer
                   GrapeOAS::ApiModel::Schema.new(type: "integer")
                 elsif [Float, BigDecimal].include?(primitive)
                   GrapeOAS::ApiModel::Schema.new(type: "number")
                 elsif [TrueClass, FalseClass].include?(primitive)
                   GrapeOAS::ApiModel::Schema.new(type: "boolean")
                 else
                   GrapeOAS::ApiModel::Schema.new(type: "string")
                 end

        # Nullability
        schema.nullable = true if nullable?(dry_type, constraints)

        # Enum
        schema.enum = enum_vals if enum_vals
        schema.enum = constraints.enum if constraints.enum && schema.enum.nil?

        # Meta-driven constraints
        apply_string_meta(schema, meta) if schema.type == "string"
        apply_numeric_meta(schema, meta) if %w[integer number].include?(schema.type)
        apply_array_meta(schema, meta) if schema.type == "array"

        # Rule/AST-driven constraints
        apply_rule_constraints(schema, constraints)

        attach_unhandled(schema, constraints)

        schema
      end

      def nullable?(dry_type, constraints)
        meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
        return true if dry_type.respond_to?(:optional?) && dry_type.optional?
        return true if meta[:maybe]
        return true if constraints&.nullable

        false
      end

      def derive_primitive_and_member(dry_type)
        # unwrap constructors/sums where possible
        core = unwrap_type(dry_type)

        if defined?(Dry::Types::Array::Member) && core.respond_to?(:type) && core.type.is_a?(Dry::Types::Array::Member)
          return [Array, core.type.member]
        end

        if core.respond_to?(:member) && core.respond_to?(:primitive) && core.primitive == Array
          return [Array, core.member]
        end

        primitive = core.respond_to?(:primitive) ? core.primitive : nil
        [primitive, nil]
      end

      def unwrap_type(dry_type)
        current = dry_type
        seen = 0
        while current.respond_to?(:type) && seen < 5
          inner = current.type
          break if inner.equal?(current)

          current = inner
          seen += 1
        end
        current
      end

      def apply_string_meta(schema, meta)
        schema.min_length = meta[:min_size] || meta[:min_length] if meta[:min_size] || meta[:min_length]
        schema.max_length = meta[:max_size] || meta[:max_length] if meta[:max_size] || meta[:max_length]
        schema.pattern = meta[:pattern] if meta[:pattern]
      end

      def apply_array_meta(schema, meta)
        schema.min_items = meta[:min_size] || meta[:min_items] if meta[:min_size] || meta[:min_items]
        schema.max_items = meta[:max_size] || meta[:max_items] if meta[:max_size] || meta[:max_items]
      end

      def apply_numeric_meta(schema, meta)
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

      def apply_rule_constraints(schema, constraints)
        return unless constraints

        case schema.type
        when "string"
          schema.min_length ||= constraints.min_size if constraints.min_size
          schema.max_length ||= constraints.max_size if constraints.max_size
          schema.pattern ||= constraints.pattern if constraints.pattern
        when "array"
          schema.min_items ||= constraints.min_size if constraints.min_size
          schema.max_items ||= constraints.max_size if constraints.max_size
        end

        if %w[integer number].include?(schema.type)
          numeric_min = constraints.minimum || constraints.min_size
          numeric_max = constraints.maximum || constraints.max_size
          schema.minimum ||= numeric_min if numeric_min
          schema.maximum ||= numeric_max if numeric_max
          schema.exclusive_minimum ||= constraints.exclusive_minimum
          schema.exclusive_maximum ||= constraints.exclusive_maximum
        end

        schema.enum ||= constraints.enum if constraints.enum
        schema.nullable = true if constraints.nullable

        if constraints.extensions&.key?("multipleOf")
          schema.extensions ||= {}
          schema.extensions["multipleOf"] ||= constraints.extensions["multipleOf"]
        end

        if constraints.excluded_values
          schema.extensions ||= {}
          schema.extensions["x-excludedValues"] ||= constraints.excluded_values
        end

        if constraints.type_predicate
          schema.extensions ||= {}
          schema.extensions["x-typePredicate"] ||= constraints.type_predicate
        end

        if constraints.parity
          schema.extensions ||= {}
          schema.extensions["x-numberParity"] ||= constraints.parity.to_s
        end

        schema.format ||= constraints.format if constraints.format
      end

      def attach_unhandled(schema, constraints)
        return unless constraints&.unhandled_predicates

        filtered = Array(constraints.unhandled_predicates) - %i[key? key str? int? bool? boolean? array? hash? number?
                                                                float?]
        return if filtered.empty?

        schema.extensions ||= {}
        schema.extensions["x-unhandledPredicates"] = filtered
      end

      def extract_enum_from_type(dry_type)
        return unless dry_type.respond_to?(:values)

        vals = dry_type.values
        vals if vals.is_a?(Array)
      rescue StandardError
        nil
      end

      def extract_rule_constraints(contract)
        constraints = Hash.new { |h, k| h[k] = ConstraintSet.new(unhandled_predicates: []) }

        if contract.respond_to?(:rules)
          contract.rules.each do |name, rule|
            ast = rule.respond_to?(:to_ast) ? rule.to_ast : rule
            c = walk_ast(ast)
            # infer requiredness: required rules are usually :and, optional via :implication
            c.required = ast[0] != :implication if ast.is_a?(Array)
            merge_constraints(constraints[name], c)
          end
        end

        if contract.respond_to?(:types)
          contract.types.each do |name, dry_type|
            next unless dry_type.respond_to?(:rule_ast) || (dry_type.respond_to?(:meta) && dry_type.meta[:rules])

            asts = dry_type.respond_to?(:rule_ast) ? dry_type.rule_ast : dry_type.meta[:rules]
            Array(asts).each do |ast|
              merge_constraints(constraints[name], walk_ast(ast))
            end
          end
        end

        constraints
      rescue StandardError
        {}
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
          case tag
          when :predicate
            handle_predicate(node[1], constraints)
          when :rule
            visit(node[1], constraints)
          when :and, :implication
            Array(node[1]).each { |child| visit(child, constraints) }
          when :or
            # Best-effort: collect constraints common to all branches
            branches = Array(node[1]).map { |child| branch_constraints(child) }
            common = intersect_branches(branches)
            merge_constraints(constraints, common)
          when :not
            visit(node[1], constraints)
          when :key
            visit(node[1][1], constraints) if node[1].is_a?(Array)
          when :each
            visit(node[1], constraints)
          else
            Array(node[1]).each { |child| visit(child, constraints) }
          end
        end
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

      def handle_predicate(pred_node, constraints)
        return unless pred_node.is_a?(Array)

        name = pred_node[0]
        args = Array(pred_node[1])

        case name
        when :key?
          constraints.required = true if constraints.required.nil?
        when :size?, :min_size?
          min_val = extract_numeric_arg(args[0])
          max_val = extract_numeric_arg(args[1]) if name == :size?
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        when :max_size?
          val = extract_numeric_arg(args.first)
          constraints.max_size = val if val
        when :range?
          rng = args.first.is_a?(Range) ? args.first : extract_range_arg(args.first)
          if rng
            constraints.minimum = rng.begin if rng.begin
            constraints.maximum = rng.end if rng.end
            constraints.exclusive_maximum = rng.exclude_end?
          end
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
        when :gteq?
          constraints.minimum = extract_numeric_arg(args.first)
        when :min?
          constraints.minimum = extract_numeric_arg(args.first)
        when :lt?
          constraints.maximum = extract_numeric_arg(args.first)
          constraints.exclusive_maximum = true if constraints.maximum
        when :lteq?
          constraints.maximum = extract_numeric_arg(args.first)
        when :max?
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
          val = extract_numeric_arg(args.first)
          constraints.extensions ||= {}
          constraints.extensions["multipleOf"] ||= val if val
        when :bytesize?, :max_bytesize?, :min_bytesize?
          min_val = extract_numeric_arg(args[0]) if %i[bytesize? min_bytesize?].include?(name)
          max_source = name == :bytesize? ? args[1] : args[0]
          max_val = extract_numeric_arg(max_source) if %i[bytesize? max_bytesize?].include?(name)
          constraints.min_size = min_val if min_val
          constraints.max_size = max_val if max_val
        when :true?
          constraints.enum = [true]
        when :false?
          constraints.enum = [false]
        else
          constraints.unhandled_predicates << name
        end
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
