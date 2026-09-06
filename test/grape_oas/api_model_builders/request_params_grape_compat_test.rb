# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Grape 4.0 moved documented params off `route.options[:params]` onto
    # `Route#params` (grape#2785). These tests stub that shape so they pass
    # on Grape 3.x (the CI matrix) without requiring Grape HEAD.
    class RequestParamsGrapeCompatTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_reads_declared_params_from_route_params_when_options_empty
        route = grape4_route(
          params: { "name" => { required: true, type: "String" } },
          options: {},
        )
        _body_schema, params = RequestParams.new(api: @api, route: route).build

        name_param = params.find { |p| p.name == "name" }

        refute_nil name_param
        assert_equal "query", name_param.location
        assert name_param.required
        assert_equal Constants::SchemaTypes::STRING, name_param.schema.type
      end

      def test_prefers_options_params_when_present
        route = grape4_route(
          params: { "from_route" => { required: true, type: "Integer" } },
          options: { params: { "from_options" => { required: true, type: "String" } } },
        )
        _body_schema, params = RequestParams.new(api: @api, route: route).build

        refute_nil(params.find { |p| p.name == "from_options" })
        assert_nil(params.find { |p| p.name == "from_route" })
      end

      def test_drops_non_hash_path_captures_from_route_params
        route = grape4_route(
          params: {
            "format" => "",
            "name" => { required: true, type: "String" }
          },
          options: {},
        )
        _body_schema, params = RequestParams.new(api: @api, route: route).build

        refute_nil(params.find { |p| p.name == "name" })
        assert_nil(params.find { |p| p.name == "format" })
      end

      private

      def grape4_route(params:, options:)
        route_class = Class.new do
          attr_reader :path, :options, :request_method, :params

          def initialize(path:, options:, request_method:, params:)
            @path = path
            @options = options
            @request_method = request_method
            @params = params
          end
        end
        route_class.new(path: "/items(.json)", options: options, request_method: "GET", params: params)
      end
    end
  end
end
