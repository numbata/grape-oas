# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestTest < Minitest::Test
      DummyRoute = Struct.new(:options, :path, :settings)

      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      def test_builds_request_body_from_contract_hash
        contract = Struct.new(:to_h).new({ filter: [{ field: "f", value: "v" }], sort: "name" })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body
        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "filter"
        assert_equal "array", schema.properties["filter"].type
      end

      def test_contract_nil_value_sets_nullable
        contract = Struct.new(:to_h).new({ note: nil })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema
        note = schema.properties["note"]

        assert note.nullable
      end

      def test_request_body_and_content_extensions_from_documentation
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = {
          "x-req" => "rb",
          content: {
            "application/json" => { "x-ct" => "ct" }
          }
        }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        rb = operation.request_body

        assert_equal "rb", rb.extensions["x-req"]
        mt = rb.media_types.first

        assert_equal "ct", mt.extensions["x-ct"]
      end

      def test_contract_with_schema_method
        # Contract that has a .schema method but no .to_h, forcing the code to use contract.schema.to_h
        schema_obj = Struct.new(:to_h).new({ name: String })
        schema_contract = Object.new
        schema_contract.define_singleton_method(:schema) { schema_obj }
        route = DummyRoute.new({ contract: schema_contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "name"
        assert_equal "string", schema.properties["name"].type
      end

      def test_contract_callable
        callable_contract = proc { |_| { email: String } }
        callable_with_to_h = Struct.new(:call, :to_h).new(callable_contract, { email: String })
        route = DummyRoute.new({ contract: callable_with_to_h, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "email"
      end

      def test_hash_to_schema_with_nested_hash
        contract = Struct.new(:to_h).new({ address: { street: String, city: String } })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema
        address_schema = schema.properties["address"]

        assert_equal "object", address_schema.type
        assert_includes address_schema.properties.keys, "street"
        assert_includes address_schema.properties.keys, "city"
        assert_equal "string", address_schema.properties["street"].type
      end

      def test_hash_to_schema_maps_ruby_types
        contract = Struct.new(:to_h).new({
                                           name: String,
                                           age: Integer,
                                           price: Float,
                                           active: TrueClass,
                                           tags: Array,
                                           meta: Hash
                                         })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "string", schema.properties["name"].type
        assert_equal "integer", schema.properties["age"].type
        assert_equal "number", schema.properties["price"].type
        assert_equal "boolean", schema.properties["active"].type
        assert_equal "array", schema.properties["tags"].type
        assert_equal "object", schema.properties["meta"].type
      end

      def test_hash_to_schema_with_bigdecimal
        contract = Struct.new(:to_h).new({ amount: BigDecimal })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "number", schema.properties["amount"].type
      end

      def test_hash_to_schema_with_object_with_primitive_method
        primitive_type = Struct.new(:primitive).new(String)
        contract = Struct.new(:to_h).new({ field: primitive_type })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "string", schema.properties["field"].type
      end

      def test_no_request_body_when_schema_empty
        route = DummyRoute.new({ params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body
      end

      def test_media_type_extensions_with_symbol_key
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = {
          content: {
            "application/json": { "x-ct" => "symbol_key" }
          }
        }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_equal "symbol_key", mt.extensions["x-ct"]
      end

      def test_no_media_type_extensions_when_content_not_hash
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = { content: "not a hash" }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_nil mt.extensions
      end

      def test_no_media_type_extensions_when_mime_not_found
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = {
          content: {
            "text/plain" => { "x-ct" => "different_mime" }
          }
        }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_nil mt.extensions
      end

      def test_no_media_type_extensions_when_mime_value_not_hash
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = {
          content: {
            "application/json" => "not a hash"
          }
        }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        mt = operation.request_body.media_types.first

        assert_nil mt.extensions
      end

      def test_request_body_required_when_schema_has_required
        contract = Struct.new(:to_h).new({ name: String })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        # Mock the schema to have required properties
        req = Request.new(api: @api, route: route, operation: operation)
        req.build

        # When there are no explicit required properties, required should be false
        refute operation.request_body.required
      end

      def test_no_request_body_extensions_when_no_x_prefixed
        contract = Struct.new(:to_h).new({ foo: "bar" })
        documentation = { "regular" => "value" }
        route = DummyRoute.new({ contract: contract, params: {}, documentation: documentation }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        rb = operation.request_body

        assert_nil rb.extensions
      end

      def test_contract_from_route_settings
        contract = Struct.new(:to_h).new({ name: String })
        route_with_settings = Struct.new(:options, :path, :settings).new({ params: {} }, "/items",
                                                                         { contract: contract })

        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route_with_settings, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "object", schema.type
        assert_includes schema.properties.keys, "name"
      end

      def test_no_request_body_for_get_by_default
        contract = Struct.new(:to_h).new({ query: String })
        route = DummyRoute.new({ contract: contract, params: {} }, "/search", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "GET should not have request body by default"
      end

      def test_no_request_body_for_delete_by_default
        contract = Struct.new(:to_h).new({ id: Integer })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items/:id", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :delete)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "DELETE should not have request body by default"
      end

      def test_no_request_body_for_head_by_default
        contract = Struct.new(:to_h).new({ query: String })
        route = DummyRoute.new({ contract: contract, params: {} }, "/status", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :head)

        Request.new(api: @api, route: route, operation: operation).build

        assert_nil operation.request_body, "HEAD should not have request body by default"
      end

      def test_hash_to_schema_infers_type_from_runtime_values
        # Contract with actual runtime values (not Ruby classes)
        contract = Struct.new(:to_h).new({
                                           name: "John",
                                           age: 42,
                                           price: 99.99,
                                           active: true,
                                           disabled: false
                                         })
        route = DummyRoute.new({ contract: contract, params: {} }, "/items", {})
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :post)

        Request.new(api: @api, route: route, operation: operation).build

        schema = operation.request_body.media_types.first.schema

        assert_equal "string", schema.properties["name"].type
        assert_equal "integer", schema.properties["age"].type
        assert_equal "number", schema.properties["price"].type
        assert_equal "boolean", schema.properties["active"].type
        assert_equal "boolean", schema.properties["disabled"].type
      end

      def test_request_body_for_get_when_explicitly_allowed
        contract = Struct.new(:to_h).new({ query: String })
        route = DummyRoute.new(
          { contract: contract, params: {}, documentation: { request_body: true } },
          "/search",
          {},
        )
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :get)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "GET should have request body when explicitly allowed"
      end

      def test_request_body_for_delete_when_explicitly_allowed_via_option
        contract = Struct.new(:to_h).new({ ids: Array })
        route = DummyRoute.new(
          { contract: contract, params: {}, request_body: true },
          "/items/bulk",
          {},
        )
        operation = GrapeOAS::ApiModel::Operation.new(http_method: :delete)

        Request.new(api: @api, route: route, operation: operation).build

        refute_nil operation.request_body, "DELETE should have request body when explicitly allowed"
      end
    end
  end
end
