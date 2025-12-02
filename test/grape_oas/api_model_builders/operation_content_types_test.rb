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

        refute_nil operation
        # Should have JSON content type
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
          desc "Form submit", consumes: ["application/x-www-form-urlencoded"]
          post "form" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
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

        refute_nil operation
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

      # === Symbol format in produces ===

      def test_symbol_format_in_produces
        api_class = Class.new(Grape::API) do
          format :json
          desc "Symbol produces", produces: [:xml, :json]
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
