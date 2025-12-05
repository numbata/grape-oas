# frozen_string_literal: true

require_relative "base"
require_relative "dry_introspector_support/contract_resolver"
require_relative "dry_introspector_support/inheritance_handler"
require_relative "dry_introspector_support/type_schema_builder"

module GrapeOAS
  module Introspectors
    # Introspector for Dry::Validation contracts and Dry::Schema.
    # Extracts an ApiModel schema from contract definitions.
    class DryIntrospector
      extend Base

      # Re-export ConstraintSet for external use
      ConstraintSet = DryIntrospectorSupport::ConstraintExtractor::ConstraintSet

      # Checks if the subject is a Dry contract or schema.
      #
      # @param subject [Object] The object to check
      # @return [Boolean] true if subject is a Dry contract/schema
      def self.handles?(subject)
        # Check for Dry::Validation::Contract class
        return true if dry_contract_class?(subject)

        # Check for schema with types (instantiated contract or schema result)
        return true if subject.respond_to?(:schema) && subject.schema.respond_to?(:types)

        # Check for direct schema object
        subject.respond_to?(:types)
      end

      # Builds a schema from a Dry contract or schema.
      #
      # @param subject [Object] Contract class, instance, or schema
      # @param stack [Array] Recursion stack for cycle detection
      # @param registry [Hash] Schema registry for caching
      # @return [ApiModel::Schema, nil] The built schema
      def self.build_schema(subject, stack: [], registry: {})
        new(subject, stack: stack, registry: registry).build
      end

      # Legacy class method for backward compatibility.
      # @deprecated Use build_schema instead
      def self.build(contract, stack: [], registry: {})
        build_schema(contract, stack: stack, registry: registry)
      end

      def self.dry_contract_class?(subject)
        defined?(Dry::Validation::Contract) && subject.is_a?(Class) && subject < Dry::Validation::Contract
      end
      private_class_method :dry_contract_class?

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
