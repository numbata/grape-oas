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

        private

        def mock_route(options = {})
          OpenStruct.new(options: options)
        end
      end
    end
  end
end
