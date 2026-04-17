# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class ContentTypeResolverMemoizationTest < Minitest::Test
      class ResolverHost
        include Concerns::ContentTypeResolver

        attr_reader :api, :app, :route

        def initialize(api:, app:, route:)
          @api = api
          @app = app
          @route = route
        end

        public :default_format_from_app_or_api, :content_types_from_app_or_api
      end

      class StubApp
        attr_accessor :default_format_value, :content_types_value,
                      :default_format_calls, :content_types_calls

        def initialize
          @default_format_calls = 0
          @content_types_calls = 0
        end

        def default_format
          @default_format_calls += 1
          @default_format_value
        end

        def content_types
          @content_types_calls += 1
          @content_types_value
        end
      end

      class StubApiWithFormat < GrapeOAS::ApiModel::API
        attr_accessor :default_format_value, :content_types_value,
                      :default_format_calls, :content_types_calls

        def initialize(title: "Api Stub", version: "1.0")
          super
          @default_format_calls = 0
          @content_types_calls = 0
        end

        def default_format
          @default_format_calls += 1
          @default_format_value
        end

        def content_types
          @content_types_calls += 1
          @content_types_value
        end
      end

      StubRoute = Struct.new(:options, :settings) do
        def self.empty
          new({}, {})
        end
      end

      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
        @app = StubApp.new
        @route = Object.new
      end

      def test_default_format_is_memoized_per_api
        @app.default_format_value = :json

        host = ResolverHost.new(api: @api, app: @app, route: @route)

        assert_equal :json, host.default_format_from_app_or_api
        assert_equal :json, host.default_format_from_app_or_api
        assert_equal :json, host.default_format_from_app_or_api

        assert_equal 1, @app.default_format_calls,
                     "app.default_format should only be invoked once per (api, app) pair"
      end

      def test_default_format_cache_is_scoped_per_api_instance
        @app.default_format_value = :json
        other_api = GrapeOAS::ApiModel::API.new(title: "Other", version: "1.0")

        host1 = ResolverHost.new(api: @api, app: @app, route: @route)
        host2 = ResolverHost.new(api: other_api, app: @app, route: @route)

        host1.default_format_from_app_or_api
        host1.default_format_from_app_or_api
        host2.default_format_from_app_or_api

        assert_equal 2, @app.default_format_calls,
                     "cache must not leak between API instances"
      end

      def test_default_format_falls_back_to_uncached_when_api_has_no_builder_cache
        bare_api = Object.new
        @app.default_format_value = :json

        host = ResolverHost.new(api: bare_api, app: @app, route: @route)
        host.default_format_from_app_or_api
        host.default_format_from_app_or_api

        assert_equal 2, @app.default_format_calls,
                     "no memoization should occur when api does not expose builder_cache"
      end

      def test_default_format_caches_nil_value
        @app.default_format_value = nil

        host = ResolverHost.new(api: @api, app: @app, route: @route)
        3.times { host.default_format_from_app_or_api }

        assert_equal 1, @app.default_format_calls, "nil must be cached like any other value"
      end

      def test_default_format_memoizes_via_api_branch
        api = StubApiWithFormat.new
        api.default_format_value = :xml

        host = ResolverHost.new(api: api, app: @app, route: @route)
        3.times { host.default_format_from_app_or_api }

        assert_equal 1, api.default_format_calls,
                     "api.default_format must be invoked once even when api is the source"
        assert_equal 0, @app.default_format_calls,
                     "app.default_format must not be consulted when api.default_format answers"
      end

      def test_content_types_is_memoized_per_api_and_default_format
        @app.content_types_value = { "application/json" => :json }

        host = ResolverHost.new(api: @api, app: @app, route: @route)
        host.content_types_from_app_or_api(:json)
        host.content_types_from_app_or_api(:json)
        host.content_types_from_app_or_api(:xml)

        assert_equal 2, @app.content_types_calls, "should memoize per default_format key"
      end

      def test_content_types_cache_is_scoped_per_api_instance
        @app.content_types_value = { "application/json" => :json }
        other_api = GrapeOAS::ApiModel::API.new(title: "Other", version: "1.0")

        host1 = ResolverHost.new(api: @api, app: @app, route: @route)
        host2 = ResolverHost.new(api: other_api, app: @app, route: @route)

        host1.content_types_from_app_or_api(:json)
        host1.content_types_from_app_or_api(:json)
        host2.content_types_from_app_or_api(:json)

        assert_equal 2, @app.content_types_calls,
                     "content_types cache must not leak between API instances"
      end

      def test_content_types_memoizes_via_api_branch
        api = StubApiWithFormat.new
        api.content_types_value = { "application/json" => :json }

        host = ResolverHost.new(api: api, app: @app, route: @route)
        3.times { host.content_types_from_app_or_api(:json) }

        assert_equal 1, api.content_types_calls,
                     "api.content_types must be invoked once even when api is the source"
        assert_equal 0, @app.content_types_calls,
                     "app.content_types must not be consulted when api.content_types answers"
      end

      def test_resolve_content_types_is_stable_and_memoizes_underlying_helpers
        @app.default_format_value = :json
        @app.content_types_value = {
          "application/json" => :json,
          "application/xml" => :xml
        }

        host = ResolverHost.new(api: @api, app: @app, route: StubRoute.empty)
        host.singleton_class.send(:public, :resolve_content_types)

        first = host.resolve_content_types
        second = host.resolve_content_types
        third = host.resolve_content_types

        assert_equal first, second
        assert_equal first, third
        assert_equal ["application/json"], first,
                     "default_format :json should select the application/json mime"
        assert_equal 1, @app.default_format_calls,
                     "app.default_format must be invoked once across repeated resolves"
        assert_equal 1, @app.content_types_calls,
                     "app.content_types must be invoked once across repeated resolves"
      end
    end
  end
end
