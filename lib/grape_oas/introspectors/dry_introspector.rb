# frozen_string_literal: true

require_relative "../api_model_builders/concerns/type_resolver"

module GrapeOAS
  module Introspectors
    # Extracts an ApiModel schema from a Dry::Schema contract.
    # Delegates constraint extraction to ConstraintExtractor.
    class DryIntrospector
      include GrapeOAS::ApiModelBuilders::Concerns::TypeResolver

      # Re-export ConstraintSet for external use
      ConstraintSet = DryIntrospectorSupport::ConstraintExtractor::ConstraintSet

      def self.build(contract)
        new(contract).build
      end

      def initialize(contract)
        @contract = contract
      end

      def build
        return unless contract.respond_to?(:types)

        rule_constraints = DryIntrospectorSupport::ConstraintExtractor.extract(contract)
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

        primitive, member = DryIntrospectorSupport::TypeUnwrapper.derive_primitive_and_member(dry_type)
        enum_vals = extract_enum_from_type(dry_type)

        schema = build_base_schema(primitive, member)
        schema.nullable = true if nullable?(dry_type, constraints)
        schema.enum = enum_vals if enum_vals
        schema.enum = constraints.enum if constraints.enum && schema.enum.nil?

        apply_constraints(schema, constraints, meta)
        schema
      end

      def build_base_schema(primitive, member)
        if primitive == Array
          items_schema = member ? build_schema_for_type(member) : default_string_schema
          GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
        else
          build_schema_for_primitive(primitive)
        end
      end

      def apply_constraints(schema, constraints, meta)
        applier = DryIntrospectorSupport::ConstraintApplier.new(schema, constraints, meta)
        applier.apply_meta
        applier.apply_rule_constraints
      end

      def nullable?(dry_type, constraints)
        meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
        return true if dry_type.respond_to?(:optional?) && dry_type.optional?
        return true if meta[:maybe]
        return true if constraints&.nullable

        false
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
