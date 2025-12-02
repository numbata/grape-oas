# frozen_string_literal: true

require_relative "../api_model_builders/concerns/type_resolver"

module GrapeOAS
  module Introspectors
    # Extracts an ApiModel schema from a Dry::Schema contract.
    # Delegates constraint extraction to ConstraintExtractor.
    class DryIntrospector
      include GrapeOAS::ApiModelBuilders::Concerns::TypeResolver

      # Maximum depth for unwrapping nested Dry::Types (prevents infinite loops)
      MAX_TYPE_UNWRAP_DEPTH = 5

      # Re-export ConstraintSet for external use
      ConstraintSet = DrySupport::ConstraintExtractor::ConstraintSet

      def self.build(contract)
        new(contract).build
      end

      def initialize(contract)
        @contract = contract
      end

      def build
        return unless contract.respond_to?(:types)

        rule_constraints = DrySupport::ConstraintExtractor.extract(contract)
        schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)

        contract.types.each do |name, dry_type|
          constraints = rule_constraints[name]
          prop_schema = build_schema_for_type(dry_type, constraints)
          schema.add_property(name, prop_schema, required: required?(dry_type, constraints: constraints))
        end

        schema
      end

      private

      attr_reader :contract

      def required?(dry_type, constraints: nil)
        # prefer rule-derived info if present
        return constraints.required if constraints && !constraints.required.nil?

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
                   items_schema = member ? build_schema_for_type(member) : default_string_schema
                   GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
                 else
                   build_schema_for_primitive(primitive)
                 end

        # Nullability
        schema.nullable = true if nullable?(dry_type, constraints)

        # Enum
        schema.enum = enum_vals if enum_vals
        schema.enum = constraints.enum if constraints.enum && schema.enum.nil?

        # Meta-driven constraints
        apply_string_meta(schema, meta) if schema.type == Constants::SchemaTypes::STRING
        apply_numeric_meta(schema, meta) if numeric_type?(schema.type)
        apply_array_meta(schema, meta) if schema.type == Constants::SchemaTypes::ARRAY

        # Rule/AST-driven constraints
        apply_rule_constraints(schema, constraints)

        attach_unhandled(schema, constraints)

        schema
      end

      def numeric_type?(type)
        [Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER].include?(type)
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
        return [Array, core.member] if core.respond_to?(:member) && core.respond_to?(:primitive) && core.primitive == Array

        primitive = core.respond_to?(:primitive) ? core.primitive : nil
        [primitive, nil]
      end

      def unwrap_type(dry_type)
        current = dry_type
        depth = 0
        while current.respond_to?(:type) && depth < MAX_TYPE_UNWRAP_DEPTH
          inner = current.type
          break if inner.equal?(current)

          current = inner
          depth += 1
        end
        current
      end

      def apply_string_meta(schema, meta)
        min_length = extract_min_constraint(meta)
        max_length = extract_max_constraint(meta)
        schema.min_length = min_length if min_length
        schema.max_length = max_length if max_length
        schema.pattern = meta[:pattern] if meta[:pattern]
      end

      def apply_array_meta(schema, meta)
        min_items = extract_min_constraint(meta, :min_items)
        max_items = extract_max_constraint(meta, :max_items)
        schema.min_items = min_items if min_items
        schema.max_items = max_items if max_items
      end

      # Extract minimum constraint, supporting multiple key names
      def extract_min_constraint(meta, specific_key = :min_length)
        meta[:min_size] || meta[specific_key]
      end

      # Extract maximum constraint, supporting multiple key names
      def extract_max_constraint(meta, specific_key = :max_length)
        meta[:max_size] || meta[specific_key]
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

        apply_type_specific_constraints(schema, constraints)
        apply_common_constraints(schema, constraints)
        apply_extension_constraints(schema, constraints)
      end

      def apply_type_specific_constraints(schema, constraints)
        case schema.type
        when Constants::SchemaTypes::STRING
          schema.min_length ||= constraints.min_size if constraints.min_size
          schema.max_length ||= constraints.max_size if constraints.max_size
          schema.pattern ||= constraints.pattern if constraints.pattern
        when Constants::SchemaTypes::ARRAY
          schema.min_items ||= constraints.min_size if constraints.min_size
          schema.max_items ||= constraints.max_size if constraints.max_size
        when Constants::SchemaTypes::INTEGER, Constants::SchemaTypes::NUMBER
          apply_numeric_constraints(schema, constraints)
        end
      end

      def apply_numeric_constraints(schema, constraints)
        numeric_min = constraints.minimum || constraints.min_size
        numeric_max = constraints.maximum || constraints.max_size
        schema.minimum ||= numeric_min if numeric_min
        schema.maximum ||= numeric_max if numeric_max
        schema.exclusive_minimum ||= constraints.exclusive_minimum
        schema.exclusive_maximum ||= constraints.exclusive_maximum
      end

      def apply_common_constraints(schema, constraints)
        schema.enum ||= constraints.enum if constraints.enum
        schema.nullable = true if constraints.nullable
        schema.format ||= constraints.format if constraints.format
      end

      def apply_extension_constraints(schema, constraints)
        apply_extension(schema, "multipleOf", constraints.extensions&.dig("multipleOf"))
        apply_extension(schema, "x-excludedValues", constraints.excluded_values)
        apply_extension(schema, "x-typePredicate", constraints.type_predicate)
        apply_extension(schema, "x-numberParity", constraints.parity&.to_s)
      end

      def apply_extension(schema, key, value)
        return unless value

        schema.extensions ||= {}
        schema.extensions[key] ||= value
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
      rescue NoMethodError
        nil
      end
    end
  end
end
