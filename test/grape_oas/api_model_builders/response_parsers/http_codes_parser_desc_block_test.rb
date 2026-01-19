# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      class HttpCodesParserDescBlockTest < Minitest::Test
        def setup
          @parser = HttpCodesParser.new
        end

        def test_applicable_with_desc_block_success
          route = mock_route_with_desc_block(success: { model: "UserEntity" })

          assert @parser.applicable?(route)
        end

        def test_applicable_with_desc_block_failure
          route = mock_route_with_desc_block(failure: [400, "Bad Request"])

          assert @parser.applicable?(route)
        end

        def test_applicable_with_desc_block_entity
          route = mock_route_with_desc_block(entity: "UserEntity")

          assert @parser.applicable?(route)
        end

        def test_not_applicable_without_desc_block_or_options
          route = mock_route

          refute @parser.applicable?(route)
        end

        def test_parse_desc_block_success
          route = mock_route_with_desc_block(
            success: { code: 201, model: "UserEntity", message: "Created" },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          spec = specs.first

          assert_equal 201, spec[:code]
          assert_equal "Created", spec[:message]
          assert_equal "UserEntity", spec[:entity]
        end

        def test_parse_desc_block_multiple_success
          route = mock_route_with_desc_block(
            success: [
              { code: 200, model: "UserEntity", as: "user" },
              { code: 201, model: "ProfileEntity", as: "profile" }
            ],
          )

          specs = @parser.parse(route)

          assert_equal 2, specs.size
          assert_equal 200, specs[0][:code]
          assert_equal "user", specs[0][:as]
          assert_equal 201, specs[1][:code]
          assert_equal "profile", specs[1][:as]
        end

        def test_parse_desc_block_entity
          route = mock_route_with_desc_block(entity: "DefaultEntity")

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          spec = specs.first

          assert_equal 200, spec[:code]
          assert_equal "DefaultEntity", spec[:entity]
        end

        def test_parse_both_options_and_desc_block
          route = mock_route(
            options: { success: { model: "OptionsEntity" } },
            settings: { description: { success: { model: "DescEntity" } } },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal "OptionsEntity", specs.first[:entity]
        end

        def test_desc_block_takes_precedence_over_plain_entity_option
          # When route.options has only :entity (no http_codes/success/failure)
          # and desc block has response definitions, desc block should win
          route = mock_route(
            options: { entity: "OptionsEntity" },
            settings: { description: { success: { code: 201, model: "DescEntity", message: "Created" } } },
          )

          specs = @parser.parse(route)

          assert_equal 1, specs.size
          assert_equal 201, specs.first[:code]
          assert_equal "DescEntity", specs.first[:entity]
          assert_equal "Created", specs.first[:message]
        end

        private

        def mock_route_with_desc_block(desc_data)
          mock_route(settings: { description: desc_data })
        end

        def mock_route(options: {}, settings: {})
          route = Object.new
          route.define_singleton_method(:options) { options }
          route.define_singleton_method(:settings) { settings }
          route
        end
      end
    end
  end
end
