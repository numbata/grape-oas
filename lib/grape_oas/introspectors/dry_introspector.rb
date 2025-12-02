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

      def self.build(contract, stack: [], registry: {})
        new(contract, stack: stack, registry: registry).build
      end

      def initialize(contract, stack: [], registry: {})
        @contract = contract
        @stack = stack
        @registry = registry
      end

      def build
        return unless contract_schema.respond_to?(:types)

        # Check for inheritance - use allOf for child contracts
        parent_contract = find_parent_contract
        return build_inherited_schema(parent_contract) if parent_contract

        # Build flat schema for non-inherited contracts
        build_flat_schema
      end

      private

      # Build a flat schema with all properties (no inheritance)
      def build_flat_schema
        rule_constraints = DryIntrospectorSupport::ConstraintExtractor.extract(contract_schema)
        schema = GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          canonical_name: contract_canonical_name,
        )

        contract_schema.types.each do |name, dry_type|
          constraints = rule_constraints[name]
          prop_schema = build_schema_for_type(dry_type, constraints)
          schema.add_property(name, prop_schema, required: required?(dry_type, constraints: constraints))
        end

        @registry[contract_class] = schema
        schema
      end

      # Build schema for inherited contract using allOf composition
      def build_inherited_schema(parent_contract)
        # Build parent schema first
        parent_schema = self.class.new(parent_contract, stack: @stack, registry: @registry).build

        # Build child-only properties
        child_schema = build_child_only_schema(parent_contract)

        # Create allOf schema
        schema = GrapeOAS::ApiModel::Schema.new(
          canonical_name: contract_class.name,
          all_of: [parent_schema, child_schema],
        )

        @registry[contract_class] = schema
        schema
      end

      # Build schema containing only this contract's own properties (not inherited)
      def build_child_only_schema(parent_contract)
        child_schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        parent_keys = parent_contract_types(parent_contract)
        rule_constraints = DryIntrospectorSupport::ConstraintExtractor.extract(contract_schema)

        contract_schema.types.each do |name, dry_type|
          # Skip inherited properties
          next if parent_keys.include?(name.to_s)

          constraints = rule_constraints[name]
          prop_schema = build_schema_for_type(dry_type, constraints)
          child_schema.add_property(name, prop_schema, required: required?(dry_type, constraints: constraints))
        end

        child_schema
      end

      # Find parent contract class if this contract inherits from another
      def find_parent_contract
        return nil unless defined?(Dry::Validation::Contract)

        parent = contract_class.superclass
        return nil unless parent && parent < Dry::Validation::Contract && parent != Dry::Validation::Contract
        return nil unless parent.respond_to?(:schema)

        parent
      end

      # Get type keys from parent contract
      def parent_contract_types(parent_contract)
        return [] unless parent_contract.respond_to?(:schema)

        parent_contract.schema.types.keys.map(&:to_s)
      end

      # Get the contract class (handles both class and instance)
      def contract_class
        @contract.is_a?(Class) ? @contract : @contract.class
      end

      # Get the schema from contract (handles both class and instance)
      def contract_schema
        if @contract.is_a?(Class)
          @contract.respond_to?(:schema) ? @contract.schema : @contract
        else
          @contract.respond_to?(:schema) ? @contract.class.schema : @contract
        end
      end

      # Get canonical name only for proper Contract classes (not Dry::Schema objects)
      def contract_canonical_name
        return contract_class.name if is_validation_contract?

        nil
      end

      # Check if this is a Dry::Validation::Contract (class or instance)
      def is_validation_contract?
        return false unless defined?(Dry::Validation::Contract)

        if @contract.is_a?(Class)
          @contract < Dry::Validation::Contract
        else
          @contract.is_a?(Dry::Validation::Contract)
        end
      end

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

        # Check for Sum type first (TypeA | TypeB) -> anyOf
        return build_any_of_schema(dry_type) if DryIntrospectorSupport::TypeUnwrapper.sum_type?(dry_type)

        primitive, member = DryIntrospectorSupport::TypeUnwrapper.derive_primitive_and_member(dry_type)
        enum_vals = extract_enum_from_type(dry_type)

        schema = build_base_schema(primitive, member)
        schema.nullable = true if nullable?(dry_type, constraints)
        schema.enum = enum_vals if enum_vals
        schema.enum = constraints.enum if constraints.enum && schema.enum.nil?

        apply_constraints(schema, constraints, meta)
        schema
      end

      # Build anyOf schema from Sum type (TypeA | TypeB)
      def build_any_of_schema(sum_type)
        types = DryIntrospectorSupport::TypeUnwrapper.extract_sum_types(sum_type)

        any_of_schemas = types.map do |t|
          build_schema_for_sum_member(t)
        end

        GrapeOAS::ApiModel::Schema.new(any_of: any_of_schemas)
      end

      # Build schema for a single member of a Sum type
      def build_schema_for_sum_member(dry_type)
        # Handle Hash schemas (Types::Hash.schema(...))
        return build_hash_schema(dry_type) if hash_schema_type?(dry_type)

        # Fall back to regular type handling
        build_schema_for_type(dry_type)
      end

      # Check if type is a Hash schema with keys
      def hash_schema_type?(dry_type)
        return true if dry_type.respond_to?(:keys) && dry_type.keys.any?

        # Check for wrapped types
        unwrapped = DryIntrospectorSupport::TypeUnwrapper.unwrap(dry_type)
        unwrapped.respond_to?(:keys) && unwrapped.keys.any?
      end

      # Build schema from a Dry::Types::Hash schema
      def build_hash_schema(dry_type)
        schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        unwrapped = DryIntrospectorSupport::TypeUnwrapper.unwrap(dry_type)

        return schema unless unwrapped.respond_to?(:keys)

        unwrapped.keys.each do |key|
          key_name = key.respond_to?(:name) ? key.name.to_s : key.to_s
          key_type = key.respond_to?(:type) ? key.type : nil

          prop_schema = key_type ? build_schema_for_type(key_type) : default_string_schema
          required = key.respond_to?(:required?) ? key.required? : true
          schema.add_property(key_name, prop_schema, required: required)
        end

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
