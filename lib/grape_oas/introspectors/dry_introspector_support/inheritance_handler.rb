# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Handles contract inheritance detection and allOf schema building.
      class InheritanceHandler
        def initialize(contract_resolver, stack:, registry:)
          @contract_resolver = contract_resolver
          @stack = stack
          @registry = registry
        end

        # Finds parent contract class if this contract inherits from another.
        #
        # @return [Class, nil] the parent contract class or nil
        def find_parent_contract
          return nil unless defined?(Dry::Validation::Contract)

          parent = @contract_resolver.contract_class.superclass
          return nil unless parent && parent < Dry::Validation::Contract && parent != Dry::Validation::Contract
          return nil unless parent.respond_to?(:schema)

          parent
        end

        # Checks if the contract has a parent contract.
        #
        # @return [Boolean] true if inherited
        def inherited?
          !find_parent_contract.nil?
        end

        # Builds an inherited schema using allOf composition.
        #
        # @param parent_contract [Class] the parent contract class
        # @param type_schema_builder [TypeSchemaBuilder] builder for type schemas
        # @return [ApiModel::Schema] the composed schema
        def build_inherited_schema(parent_contract, type_schema_builder)
          # Build parent schema first
          parent_schema = DryIntrospector.new(parent_contract, stack: @stack, registry: @registry).build

          # Build child-only properties
          child_schema = build_child_only_schema(parent_contract, type_schema_builder)

          # Create allOf schema
          schema = ApiModel::Schema.new(
            canonical_name: @contract_resolver.contract_class.name,
            all_of: [parent_schema, child_schema],
          )

          @registry[@contract_resolver.contract_class] = schema
          schema
        end

        # Gets type keys from parent contract.
        #
        # @param parent_contract [Class] the parent contract class
        # @return [Array<String>] list of parent type keys
        def parent_contract_types(parent_contract)
          return [] unless parent_contract.respond_to?(:schema)

          parent_contract.schema.types.keys.map(&:to_s)
        end

        private

        def build_child_only_schema(parent_contract, type_schema_builder)
          child_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          parent_keys = parent_contract_types(parent_contract)
          rule_constraints = ConstraintExtractor.extract(@contract_resolver.contract_schema)

          @contract_resolver.contract_schema.types.each do |name, dry_type|
            # Skip inherited properties
            next if parent_keys.include?(name.to_s)

            constraints = rule_constraints[name]
            prop_schema = type_schema_builder.build_schema_for_type(dry_type, constraints)
            child_schema.add_property(name, prop_schema, required: type_schema_builder.required?(dry_type, constraints))
          end

          child_schema
        end
      end
    end
  end
end
