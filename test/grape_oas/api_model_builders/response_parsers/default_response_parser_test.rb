# frozen_string_literal: true

require "test_helper"
require "ostruct"

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      class DefaultResponseParserTest < Minitest::Test
        def setup
          @parser = DefaultResponseParser.new
        end

        def test_always_applicable
          route = mock_route

          assert @parser.applicable?(route)
        end

        def test_returns_200_by_default
          route = mock_route

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "200", specs[0][:code]
          assert_equal "Success", specs[0][:message]
        end

        def test_uses_custom_default_status
          route = mock_route(default_status: 201)

          specs = @parser.parse(route)

          assert_equal "201", specs[0][:code]
        end

        def test_uses_route_entity
          route = mock_route(entity: "UserEntity")

          specs = @parser.parse(route)

          assert_equal "UserEntity", specs[0][:entity]
        end

        def test_sets_headers_to_nil
          route = mock_route

          specs = @parser.parse(route)

          assert_nil specs[0][:headers]
        end

        private

        def mock_route(options = {})
          OpenStruct.new(options: options)
        end
      end
    end
  end
end
