# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Unit tests for extract_contract_from_grape_validations covering both
    # Grape < 3.2 (Hash-based validations) and Grape >= 3.2 (validator instances).
    class RequestContractExtractionTest < Minitest::Test
      def api
        @api ||= ApiModel::API.new(title: "t", version: "v")
      end

      def test_extracts_contract_from_hash_based_validations
        contract = Dry::Schema.Params { required(:name).filled(:string) }

        validations = [
          { validator_class: Grape::Validations::Validators::ContractScopeValidator,
            opts: { schema: contract } }
        ]

        schema = build_with_validations(validations)

        assert schema.properties.key?("name"), "Should extract contract from hash-based validation"
      end

      def test_extracts_contract_from_validator_instance
        contract = Dry::Schema.Params { required(:email).filled(:string) }

        # Grape 3.2 stores frozen validator instances with no public schema accessor.
        # Use allocate to avoid constructor differences between Grape versions.
        validator = Grape::Validations::Validators::ContractScopeValidator.allocate
        validator.instance_variable_set(:@schema, contract)

        schema = build_with_validations([validator])

        assert schema.properties.key?("email"), "Should extract contract from validator instance"
      end

      def test_warns_when_validator_instance_has_no_schema
        validator = Grape::Validations::Validators::ContractScopeValidator.allocate

        log_output = capture_grape_oas_log do
          build_request_with_validations([validator])
        end

        assert_match(/ContractScopeValidator found but @schema is nil/, log_output)
      end

      private

      def build_with_validations(validations)
        build_request_with_validations(validations).request_body.media_types.first.schema
      end

      def build_request_with_validations(validations)
        route_hash = { saved_validations: validations }
        setting = Struct.new(:route).new(route_hash)
        app = Struct.new(:inheritable_setting).new(setting)
        route = Struct.new(:app, :path, :options).new(app, "/test(.json)", { params: {} })

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)
        Request.new(api: api, route: route, operation: operation).build
        operation
      end
    end
  end
end
