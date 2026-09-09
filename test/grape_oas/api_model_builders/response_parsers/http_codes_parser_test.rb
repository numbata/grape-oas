# frozen_string_literal: true

require "test_helper"
require "ostruct"

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      class HttpCodesParserTest < Minitest::Test
        def setup
          @parser = HttpCodesParser.new
        end

        def test_applicable_when_http_codes_present
          route = mock_route(http_codes: [200])

          assert @parser.applicable?(route)
        end

        def test_applicable_when_failure_present
          route = mock_route(failure: [[404, "Not found"]])

          assert @parser.applicable?(route)
        end

        def test_applicable_when_success_present
          route = mock_route(success: { code: 201 })

          assert @parser.applicable?(route)
        end

        def test_not_applicable_when_no_codes_present
          route = mock_route

          refute @parser.applicable?(route)
        end

        def test_parses_http_codes_as_hash
          route = mock_route(
            http_codes: [
              { code: 200, message: "OK", model: "Entity" }
            ],
            entity: "DefaultEntity",
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 200, specs[0][:code]
          assert_equal "OK", specs[0][:message]
          assert_equal "Entity", specs[0][:entity]
        end

        def test_normalizes_symbolic_statuses
          route = mock_route(
            success: [
              { code: :ok, message: "OK" },
              { code: :"2XX", message: "Success" }
            ],
          )

          specs = @parser.parse(route)
          codes = specs.map { |spec| spec[:code] }

          assert_equal [200, "2XX"], codes
        end

        def test_deduplicates_symbolic_status_before_appending_desc_entity
          data = { http_codes: [{ code: :ok, message: "OK" }], entity: "Entity" }
          route = OpenStruct.new(options: data, settings: { description: data })

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 200, specs.first[:code]
          assert_equal "Entity", specs.first[:entity]
        end

        def test_rejects_unknown_symbolic_status
          route = mock_route(success: { code: :unknown_status })

          assert_raises(ArgumentError) { @parser.parse(route) }
        end

        def test_parses_http_codes_with_status_key
          route = mock_route(
            http_codes: [
              { status: 201, message: "Created" }
            ],
          )

          specs = @parser.parse(route)

          assert_equal 201, specs[0][:code]
        end

        def test_parses_http_codes_with_http_status_key
          route = mock_route(
            http_codes: [
              { http_status: 202, message: "Accepted" }
            ],
          )

          specs = @parser.parse(route)

          assert_equal 202, specs[0][:code]
        end

        def test_parses_http_codes_as_array
          route = mock_route(
            http_codes: [
              [404, "Not Found", "ErrorEntity"]
            ],
            entity: "DefaultEntity",
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 404, specs[0][:code]
          assert_equal "Not Found", specs[0][:message]
          assert_equal "ErrorEntity", specs[0][:entity]
        end

        def test_parses_http_codes_as_plain_integer
          route = mock_route(
            http_codes: [204],
            entity: "Entity",
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 204, specs[0][:code]
          assert_nil specs[0][:message]
          assert_equal "Entity", specs[0][:entity]
        end

        def test_parses_failure_option
          route = mock_route(
            failure: [
              [400, "Bad Request"],
              [404, "Not Found"]
            ],
          )

          specs = @parser.parse(route)

          assert_equal 2, specs.size
          assert_equal 400, specs[0][:code]
          assert_equal 404, specs[1][:code]
        end

        def test_parses_success_option
          route = mock_route(
            success: { code: 201, message: "Created", model: "UserEntity" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 201, specs[0][:code]
          assert_equal "Created", specs[0][:message]
          assert_equal "UserEntity", specs[0][:entity]
        end

        def test_combines_all_options
          route = mock_route(
            http_codes: [200],
            failure: [[404, "Not Found"]],
            success: { code: 201, message: "Created" },
          )

          specs = @parser.parse(route)

          assert_equal 3, specs.size
          assert_equal([200, 404, 201], specs.map { |s| s[:code] })
        end

        def test_supports_message_desc_and_description_keys
          route = mock_route(
            http_codes: [
              { code: 200, message: "message variant" },
              { code: 201, description: "description variant" },
              { code: 202, desc: "desc variant" }
            ],
          )

          specs = @parser.parse(route)

          assert_equal "message variant", specs[0][:message]
          assert_equal "description variant", specs[1][:message]
          assert_equal "desc variant", specs[2][:message]
        end

        def test_falls_back_to_route_entity
          route = mock_route(
            http_codes: [{ code: 200 }],
            entity: "RouteEntity",
          )

          specs = @parser.parse(route)

          assert_equal "RouteEntity", specs[0][:entity]
        end

        def test_uses_default_status_when_no_code_specified
          route = mock_route(
            http_codes: [{}],
            default_status: 204,
          )

          specs = @parser.parse(route)

          assert_equal "204", specs[0][:code]
        end

        def test_parses_examples_from_hash_entry
          route = mock_route(
            http_codes: [
              { code: 200, examples: { "application/json" => { id: 1, name: "John" } } }
            ],
          )

          specs = @parser.parse(route)

          assert_equal({ "application/json" => { id: 1, name: "John" } }, specs[0][:examples])
        end

        def test_parses_examples_from_array_entry
          route = mock_route(
            http_codes: [
              [404, "Not Found", nil, { "application/json" => { code: 404 } }]
            ],
          )

          specs = @parser.parse(route)

          assert_equal({ "application/json" => { code: 404 } }, specs[0][:examples])
        end

        def test_parses_examples_from_failure_hash
          route = mock_route(
            failure: [
              { code: 400, message: "Bad Request", examples: { "application/json" => { error: "invalid" } } }
            ],
          )

          specs = @parser.parse(route)

          assert_equal({ "application/json" => { error: "invalid" } }, specs[0][:examples])
        end

        def test_parses_as_key_for_multiple_present
          route = mock_route(
            success: [
              { model: "UserEntity", as: :user },
              { model: "ProfileEntity", as: :profile }
            ],
          )

          specs = @parser.parse(route)

          assert_equal 2, specs.size
          assert_equal :user, specs[0][:as]
          assert_equal :profile, specs[1][:as]
        end

        def test_parses_is_array_option
          route = mock_route(
            success: [
              { model: "ItemEntity", as: :items, is_array: true }
            ],
          )

          specs = @parser.parse(route)

          assert specs[0][:is_array]
        end

        def test_parses_required_option
          route = mock_route(
            success: [
              { model: "ItemEntity", as: :items, required: true }
            ],
          )

          specs = @parser.parse(route)

          assert specs[0][:required]
        end

        def test_applicable_when_default_present
          route = mock_route(default: { code: "default", message: "boom" })

          assert @parser.applicable?(route)
        end

        def test_applicable_when_default_response_present
          route = mock_route(default_response: { message: "boom" })

          assert @parser.applicable?(route)
        end

        def test_parses_default_option_as_oas_default
          route = mock_route(
            default: { code: "default", message: "unexpected error", model: "ErrorEntity" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "default", specs[0][:code]
          assert_equal "unexpected error", specs[0][:message]
          assert_equal "ErrorEntity", specs[0][:entity]
        end

        def test_parses_default_response_option_as_oas_default
          route = mock_route(
            default_response: { message: "unexpected error", model: "ErrorEntity" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "default", specs[0][:code]
          assert_equal "unexpected error", specs[0][:message]
          assert_equal "ErrorEntity", specs[0][:entity]
        end

        def test_prefers_default_response_over_default
          route = mock_route(
            default: { message: "old" },
            default_response: { message: "new" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "new", specs[0][:message]
        end

        def test_normalizes_string_keys_in_default_response
          route = mock_route(
            default_response: { "message" => "boom", "model" => "ErrorEntity" },
          )

          spec = @parser.parse(route).first

          assert_equal "boom", spec[:message]
          assert_equal "ErrorEntity", spec[:entity]
        end

        def test_normalizes_string_keys_in_default_response_one_of
          route = mock_route(
            default_response: { "one_of" => [{ "model" => "ErrorEntity" }] },
          )

          one_of = @parser.parse(route).first[:one_of]

          assert_equal "ErrorEntity", one_of.first[:model]
        end

        def test_default_response_overrides_http_codes_default
          route = mock_route(
            http_codes: [{ code: "default", message: "Legacy" }],
            default_response: { message: "Canonical" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "Canonical", specs.first[:message]
        end

        def test_default_response_can_override_route_array_setting
          route = mock_route(
            default_response: { model: "ErrorEntity", is_array: false },
            is_array: true,
          )

          spec = @parser.parse(route).first

          refute spec[:is_array]
        end

        def test_default_response_ignores_numeric_code
          route = mock_route(default: { code: 400, message: "boom" })

          specs = @parser.parse(route)

          assert_equal "default", specs[0][:code]
          assert_equal "boom", specs[0][:message]
        end

        def test_default_response_without_message_uses_fallback
          route = mock_route(default: { model: "ErrorEntity" })

          specs = @parser.parse(route)

          assert_equal "Default Response", specs[0][:message]
        end

        def test_default_response_does_not_inherit_route_entity
          route = mock_route(
            default: { message: "boom" },
            entity: "SuccessEntity",
          )

          specs = @parser.parse(route)
          default_spec = specs.find { |s| s[:code] == "default" }

          assert default_spec
          assert_nil default_spec[:entity]
        end

        def test_parses_default_as_entity_class
          error_entity = Class.new
          route = mock_route(default: error_entity)

          specs = @parser.parse(route)

          assert_equal "default", specs[0][:code]
          assert_equal error_entity, specs[0][:entity]
        end

        def test_combines_default_with_success_and_failure
          route = mock_route(
            success: { code: 200, message: "OK" },
            failure: [[404, "Not Found"]],
            default: { message: "unexpected error" },
          )

          specs = @parser.parse(route)

          assert_equal([404, 200, "default"], specs.map { |s| s[:code] })
        end

        private

        def mock_route(options = {})
          OpenStruct.new(options: options)
        end
      end
    end
  end
end
