# frozen_string_literal: true

require_relative "base"
require_relative "dry_introspector_support/contract_resolver"
require_relative "dry_introspector_support/inheritance_handler"
require_relative "dry_introspector_support/type_schema_builder"
require_relative "dry_introspector_support/rule_index"

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

        # Check registry cache first (like EntityIntrospector does)
        cached = cached_schema
        return cached if cached

        parent_contract = inheritance_handler.find_parent_contract
        return inheritance_handler.build_inherited_schema(parent_contract, type_schema_builder) if parent_contract

        build_flat_schema
      end

      private

      # Returns cached schema if it exists and has properties.
      # Checks by both canonical_name (for Dry::Schema with schema_name)
      # and contract_class (for Dry::Validation::Contract).
      #
      # @return [ApiModel::Schema, nil]
      def cached_schema
        # Try canonical_name first (for Dry::Schema objects with schema_name)
        if contract_resolver.canonical_name
          cached = @registry[contract_resolver.canonical_name]
          return cached if cached && !cached.properties.empty?
        end

        # Fall back to contract_class (for Dry::Validation::Contract)
        cached = @registry[contract_resolver.contract_class]
        return cached if cached && !cached.properties.empty?

        nil
      end

      def build_flat_schema
        contract_schema = contract_resolver.contract_schema

        constraints_by_path, required_by_object_path =
          DryIntrospectorSupport::RuleIndex.build(contract_schema)

        type_schema_builder.configure_path_aware_mode(constraints_by_path, required_by_object_path)

        schema = ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          canonical_name: contract_resolver.canonical_name,
        )

        root_required = required_by_object_path.fetch("", [])

        contract_schema.types.each do |name, dry_type|
          name_s = name.to_s
          prop_schema = nil

          type_schema_builder.with_path(name_s) do
            prop_schema = type_schema_builder.build_schema_for_type(dry_type,
                                                                    type_schema_builder.constraints_for_current_path,)
          end

          schema.add_property(name, prop_schema, required: root_required.include?(name_s))
        end

        # Use canonical_name as registry key for schema objects (they don't have unique classes),
        # fall back to contract_class for Contract classes
        registry_key = contract_resolver.canonical_name || contract_resolver.contract_class
        @registry[registry_key] = schema
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
