# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class ResponseRouteDocTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_uses_documentation_responses_and_headers
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user", documentation: {
            responses: {
              201 => { message: "Created", "x-rate-limit" => 10 },
              422 => { message: "Invalid", headers: { "X-Error" => { desc: "reason", type: "string" } } }
            },
            headers: { "X-Trace" => { desc: "trace id", type: "string" } }
          }
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Response.new(api: @api, route: route)
        responses = builder.build

        codes = responses.map(&:http_status)

        assert_includes codes, "201"
        assert_includes codes, "422"

        hdrs_422 = responses.find { |r| r.http_status == "422" }.headers

        assert_equal "X-Error", hdrs_422.first[:name]

        resp_201 = responses.find { |r| r.http_status == "201" }
        hdrs_default = resp_201.headers

        assert_equal "X-Trace", hdrs_default.first[:name]
        assert_equal 10, resp_201.extensions[:"x-rate-limit"]
      end
    end
  end
end
