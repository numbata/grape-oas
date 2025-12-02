# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for x-* extension handling at various levels
    class OperationExtensionsEdgeCasesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Extensions in desc block ===

      def test_extensions_in_desc_documentation
        api_class = Class.new(Grape::API) do
          format :json
          desc "Extended endpoint", documentation: {
            "x-custom-field" => "custom-value",
            "x-rate-limit" => 100
          }
          get "extended" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
        # Extensions should be preserved
      end

      # === Multiple extensions ===

      def test_multiple_extensions
        api_class = Class.new(Grape::API) do
          format :json
          desc "Multi-extended", documentation: {
            "x-one" => 1,
            "x-two" => "two",
            "x-three" => true,
            "x-four" => { nested: "value" }
          }
          get "multi" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Extension with special characters in value ===

      def test_extension_with_special_values
        api_class = Class.new(Grape::API) do
          format :json
          desc "Special values", documentation: {
            "x-url" => "https://example.com/path?q=1&a=2",
            "x-regex" => "^[a-z]+$",
            "x-emoji" => "🚀"
          }
          get "special" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Extension with array value ===

      def test_extension_with_array_value
        api_class = Class.new(Grape::API) do
          format :json
          desc "Array extension", documentation: {
            "x-tags" => %w[tag1 tag2 tag3],
            "x-codes" => [100, 200, 300]
          }
          get "array" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Extension with nil value ===

      def test_extension_with_nil_value
        api_class = Class.new(Grape::API) do
          format :json
          desc "Nil extension", documentation: {
            "x-nullable" => nil,
            "x-valid" => "present"
          }
          get "nil" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Extension with false value ===

      def test_extension_with_false_value
        api_class = Class.new(Grape::API) do
          format :json
          desc "False extension", documentation: {
            "x-deprecated" => false,
            "x-internal" => true
          }
          get "false" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Extension without x- prefix (should be ignored) ===

      def test_non_extension_fields_ignored
        api_class = Class.new(Grape::API) do
          format :json
          desc "Normal fields", documentation: {
            desc: "Description",
            "x-extension" => "value"
          }
          get "normal" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Symbol vs string extension keys ===

      def test_symbol_extension_keys
        api_class = Class.new(Grape::API) do
          format :json
          desc "Symbol keys", documentation: {
            "x-string-key": "string",
            :"x-symbol-key" => "symbol"
          }
          get "keys" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route, app: api_class)
        operation = builder.build

        refute_nil operation
      end

      # === Deeply nested extension value ===

      def test_deeply_nested_extension_value
        api_class = Class.new(Grape::API) do
          format :json
          desc "Nested extension", documentation: {
            "x-config" => {
              level1: {
                level2: {
                  level3: "deep"
                }
              }
            }
          }
          get "nested" do
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
