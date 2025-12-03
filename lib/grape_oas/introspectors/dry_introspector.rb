# frozen_string_literal: true

require_relative "dry_introspector_support/contract_resolver"
require_relative "dry_introspector_support/inheritance_handler"
require_relative "dry_introspector_support/type_schema_builder"

module GrapeOAS
  module Introspectors
    # Extracts an ApiModel schema from a Dry::Schema contract.
    # Delegates to support classes for specific responsibilities.
    class DryIntrospector
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
        return unless contract_resolver.contract_schema.respond_to?(:types)

        parent_contract = inheritance_handler.find_parent_contract
        return inheritance_handler.build_inherited_schema(parent_contract, type_schema_builder) if parent_contract

        build_flat_schema
      end

      private

      def build_flat_schema
        rule_constraints = DryIntrospectorSupport::ConstraintExtractor.extract(contract_resolver.contract_schema)
        schema = ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          canonical_name: contract_resolver.canonical_name,
        )

        contract_resolver.contract_schema.types.each do |name, dry_type|
          constraints = rule_constraints[name]
          prop_schema = type_schema_builder.build_schema_for_type(dry_type, constraints)
          schema.add_property(name, prop_schema, required: type_schema_builder.required?(dry_type, constraints))
        end

        @registry[contract_resolver.contract_class] = schema
        schema
      end

      def contract_resolver
        @contract_resolver ||= DryIntrospectorSupport::ContractResolver.new(@contract)
      end

      def inheritance_handler
        @inheritance_handler ||= DryIntrospectorSupport::InheritanceHandler.new(
          contract_resolver,
          stack: @stack,
          registry: @registry,
        )
      end

      def type_schema_builder
        @type_schema_builder ||= DryIntrospectorSupport::TypeSchemaBuilder.new
      end
    end
  end
end
