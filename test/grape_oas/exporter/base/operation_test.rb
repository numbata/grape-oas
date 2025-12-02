# frozen_string_literal: true

require "test_helper"
require "ostruct"

module GrapeOAS
  module Exporter
    module Base
      class OperationTest < Minitest::Test
        def test_build_includes_common_fields
          op = mock_operation
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          assert_equal "test_operation", result["operationId"]
          assert_equal "Test Summary", result["summary"]
          assert_equal "Test Description", result["description"]
          assert result["deprecated"]
          assert_equal %w[users api], result["tags"]
        end

        def test_build_includes_version_specific_fields
          op = mock_operation
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          assert_equal "version_specific_value", result["customField"]
        end

        def test_build_adds_security_when_present
          op = mock_operation(security: [{ api_key: [] }])
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          assert_equal [{ api_key: [] }], result["security"]
        end

        def test_build_omits_security_when_nil
          op = mock_operation(security: nil)
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          refute result.key?("security")
        end

        def test_build_omits_security_when_empty
          op = mock_operation(security: [])
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          refute result.key?("security")
        end

        def test_build_merges_extensions
          op = mock_operation(extensions: { "x-custom" => "value", "x-rate-limit" => 100 })
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          assert_equal "value", result["x-custom"]
          assert_equal 100, result["x-rate-limit"]
        end

        def test_build_omits_extensions_when_nil
          op = mock_operation(extensions: nil)
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          refute result.key?("x-custom")
        end

        def test_build_compacts_nil_values
          op = mock_operation(
            operation_id: nil,
            summary: nil,
            description: nil,
            deprecated: nil,
          )
          operation = TestOperationImplementation.new(op, nil)

          result = operation.build

          refute result.key?("operationId")
          refute result.key?("summary")
          refute result.key?("description")
          refute result.key?("deprecated")
        end

        def test_passes_ref_tracker_to_subclass
          op = mock_operation
          ref_tracker = Set.new
          operation = TestOperationImplementation.new(op, ref_tracker)

          operation.build

          assert_equal ref_tracker, operation.last_ref_tracker
        end

        def test_passes_options_to_subclass
          op = mock_operation
          operation = TestOperationImplementation.new(op, nil, custom_option: "value")

          operation.build

          assert_equal({ custom_option: "value" }, operation.last_options)
        end

        def test_raises_not_implemented_error_without_subclass_override
          op = mock_operation
          operation = Operation.new(op, nil)

          error = assert_raises(NotImplementedError) do
            operation.build
          end

          assert_match(/must implement #build_version_specific_fields/, error.message)
        end

        private

        def mock_operation(overrides = {})
          defaults = {
            operation_id: "test_operation",
            summary: "Test Summary",
            description: "Test Description",
            deprecated: true,
            tag_names: %w[users api],
            security: nil,
            extensions: nil
          }
          OpenStruct.new(defaults.merge(overrides))
        end

        # Test implementation of Base::Operation for testing
        class TestOperationImplementation < Operation
          attr_reader :last_ref_tracker, :last_options

          def build_version_specific_fields
            @last_ref_tracker = @ref_tracker
            @last_options = @options
            { "customField" => "version_specific_value" }
          end
        end
      end
    end
  end
end
