# frozen_string_literal: true

require "test_helper"
require "ostruct"

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      class DocumentationResponsesParserTest < Minitest::Test
        def setup
          @parser = DocumentationResponsesParser.new
        end

        def test_applicable_when_documentation_responses_present
          route = mock_route(documentation: { responses: { 200 => { description: "OK" } } })

          assert @parser.applicable?(route)
        end

        def test_not_applicable_when_documentation_responses_missing
          route = mock_route(documentation: {})

          refute @parser.applicable?(route)
        end

        def test_not_applicable_when_documentation_missing
          route = mock_route

          refute @parser.applicable?(route)
        end

        def test_parses_single_response
          route = mock_route(
            documentation: {
              responses: {
                200 => { description: "Success", model: "UserEntity" }
              }
            },
            entity: "DefaultEntity",
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 200, specs[0][:code]
          assert_equal "Success", specs[0][:message]
          assert_equal "UserEntity", specs[0][:entity]
        end

        def test_parses_multiple_responses
          route = mock_route(
            documentation: {
              responses: {
                200 => { description: "OK" },
                404 => { description: "Not Found" },
                500 => { description: "Error" }
              }
            },
          )

          specs = @parser.parse(route)

          assert_equal 3, specs.size
          assert_equal([200, 404, 500], specs.map { |s| s[:code] })
          assert_equal(["OK", "Not Found", "Error"], specs.map { |s| s[:message] })
        end

        def test_extracts_headers
          route = mock_route(
            documentation: {
              responses: {
                200 => {
                  description: "OK",
                  headers: { "X-Rate-Limit" => { type: "integer" } }
                }
              }
            },
          )

          specs = @parser.parse(route)

          assert_equal({ "X-Rate-Limit" => { type: "integer" } }, specs[0][:headers])
        end

        def test_extracts_extensions
          route = mock_route(
            documentation: {
              responses: {
                200 => {
                  description: "OK",
                  "x-custom" => "value",
                  "x-another" => 123
                }
              }
            },
          )

          specs = @parser.parse(route)

          assert_equal({ "x-custom": "value", "x-another": 123 }, specs[0][:extensions])
        end

        def test_extracts_examples
          route = mock_route(
            documentation: {
              responses: {
                200 => {
                  description: "OK",
                  examples: { "application/json" => { id: 1 } }
                }
              }
            },
          )

          specs = @parser.parse(route)

          assert_equal({ "application/json" => { id: 1 } }, specs[0][:examples])
        end

        def test_falls_back_to_route_entity
          route = mock_route(
            documentation: {
              responses: {
                200 => { description: "OK" }
              }
            },
            entity: "RouteEntity",
          )

          specs = @parser.parse(route)

          assert_equal "RouteEntity", specs[0][:entity]
        end

        def test_normalizes_string_keys_to_symbols
          route = mock_route(
            documentation: {
              responses: {
                200 => { "description" => "OK", "model" => "Entity" }
              }
            },
          )

          specs = @parser.parse(route)

          assert_equal "OK", specs[0][:message]
          assert_equal "Entity", specs[0][:entity]
        end

        private

        def mock_route(options = {})
          OpenStruct.new(options: options)
        end
      end
    end
  end
end
