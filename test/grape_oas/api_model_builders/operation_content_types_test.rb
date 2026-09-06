# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for content-type / produces / consumes handling
    class OperationContentTypesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Default JSON format ===

      def test_default_json_format
        api_class = Class.new(Grape::API) do
          format :json
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        assert_equal ["application/json"], operation.consumes
        assert_equal ["application/json"], operation.produces
      end

      # === XML format ===

      def test_xml_format
        api_class = Class.new(Grape::API) do
          format :xml
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Binary format ===

      def test_binary_format
        api_class = Class.new(Grape::API) do
          format :binary
          get "download" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Custom MIME type in produces ===

      def test_custom_mime_type_produces
        api_class = Class.new(Grape::API) do
          format :json
          desc "Custom produces", produces: ["application/vnd.api+json"]
          get "custom" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Multiple produces formats ===

      def test_multiple_produces_formats
        api_class = Class.new(Grape::API) do
          format :json
          desc "Multiple formats", produces: ["application/json", "application/xml"]
          get "multi" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Consumes for POST ===

      def test_consumes_for_post
        api_class = Class.new(Grape::API) do
          format :json
          desc "Create item", consumes: ["application/json"]
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Form-urlencoded consumes ===

      def test_form_urlencoded_consumes
        api_class = Class.new(Grape::API) do
          format :json
          desc "Form submit", consumes: ["application/x-www-form-urlencoded"], produces: ["application/json"]
          post "form" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        assert_equal ["application/x-www-form-urlencoded"], operation.consumes
        assert_equal ["application/json"], operation.produces
      end

      # === Multipart form consumes ===

      def test_multipart_form_consumes
        api_class = Class.new(Grape::API) do
          format :json
          desc "File upload", consumes: ["multipart/form-data"]
          post "upload" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        assert_equal ["multipart/form-data"], operation.consumes
        assert_equal ["application/json"], operation.produces
      end

      # === Text plain format ===

      def test_text_plain_format
        api_class = Class.new(Grape::API) do
          format :txt
          get "text" do
            "plain text"
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      def test_documented_media_types_apply_to_request_and_response
        api_class = Class.new(Grape::API) do
          format :json
          desc "Documented media", documentation: { consumes: %i[json json], produces: [:xml] }
          params { requires :message, type: String }
          post("documented") { {} }
        end
        operation = Operation.new(api: @api, route: api_class.routes.first, app: api_class).build

        assert_equal ["application/json"], operation.consumes
        assert_equal ["application/xml"], operation.produces
        assert_equal ["application/json"], operation.request_body.media_types.map(&:mime_type)
        assert_equal ["application/xml"], operation.responses.first.media_types.map(&:mime_type)
      end

      def test_route_media_types_take_precedence_over_documentation
        api_class = Class.new(Grape::API) do
          format :json
          desc "Multiple encodings", consumes: ["application/json", "multipart/form-data"], produces: "text/plain",
                                     documentation: { consumes: ["application/xml"], produces: ["application/xml"] }
          params { requires :message, type: String }
          post("multiple") { "ok" }
        end
        operation = Operation.new(api: @api, route: api_class.routes.first, app: api_class).build

        assert_equal ["application/json", "multipart/form-data"], operation.request_body.media_types.map(&:mime_type)
        assert_equal ["text/plain"], operation.responses.first.media_types.map(&:mime_type)
      end

      # === Symbol format in produces ===

      def test_symbol_format_in_produces
        api_class = Class.new(Grape::API) do
          format :json
          desc "Symbol produces", produces: %i[xml json]
          get "symbols" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end
    end
  end
end
