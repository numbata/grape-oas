# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Resolves contract class, schema, and metadata from a Dry contract.
      # Handles both class and instance contracts.
      class ContractResolver
        def initialize(contract)
          @contract = contract
        end

        # Gets the contract class (handles both class and instance).
        #
        # @return [Class] the contract class
        def contract_class
          @contract.is_a?(Class) ? @contract : @contract.class
        end

        # Gets the schema from contract (handles both class and instance).
        #
        # @return [Object] the contract schema
        def contract_schema
          if @contract.is_a?(Class)
            @contract.respond_to?(:schema) ? @contract.schema : @contract
          else
            @contract.respond_to?(:schema) ? @contract.class.schema : @contract
          end
        end

        # Gets canonical name only for proper Contract classes (not Dry::Schema objects).
        #
        # @return [String, nil] the canonical name or nil
        def canonical_name
          return contract_class.name if validation_contract?

          nil
        end

        # Checks if this is a Dry::Validation::Contract (class or instance).
        #
        # @return [Boolean] true if validation contract
        def validation_contract?
          return false unless defined?(Dry::Validation::Contract)

          if @contract.is_a?(Class)
            @contract < Dry::Validation::Contract
          else
            @contract.is_a?(Dry::Validation::Contract)
          end
        end
      end
    end
  end
end
