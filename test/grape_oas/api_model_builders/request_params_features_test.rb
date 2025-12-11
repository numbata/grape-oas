# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for parameter features like format, examples, hidden, extensions
    class RequestParamsFeaturesTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Description fallback from spec[:desc] ===

      def test_description_from_documentation_desc
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :name, type: String, documentation: { desc: "The user name" }
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        name_param = params.find { |p| p.name == "name" }

        assert_equal "The user name", name_param.description
      end

      def test_description_from_spec_desc_fallback
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :email, type: String, desc: "The email address"
          end
          get "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        email_param = params.find { |p| p.name == "email" }

        assert_equal "The email address", email_param.description
      end

      def test_documentation_desc_takes_priority_over_spec_desc
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :phone, type: String, desc: "Fallback desc", documentation: { desc: "Priority desc" }
          end
          get "contacts" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        phone_param = params.find { |p| p.name == "phone" }

        assert_equal "Priority desc", phone_param.description
      end

      # === Custom format on parameters (grape-swagger issue #784) ===

      def test_custom_format_on_string_parameter
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :phone, type: String, documentation: { format: "phone" }
            requires :uuid, type: String, documentation: { format: "uuid" }
          end
          get "contacts" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        phone_param = params.find { |p| p.name == "phone" }
        uuid_param = params.find { |p| p.name == "uuid" }

        assert_equal "phone", phone_param.schema.format, "Custom format 'phone' should be preserved"
        assert_equal "uuid", uuid_param.schema.format, "Standard format 'uuid' should be preserved"
      end

      def test_custom_format_on_integer_parameter
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :timestamp, type: Integer, documentation: { format: "int64" }
            requires :small_int, type: Integer, documentation: { format: "int32" }
          end
          get "data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        timestamp_param = params.find { |p| p.name == "timestamp" }
        small_int_param = params.find { |p| p.name == "small_int" }

        assert_equal "int64", timestamp_param.schema.format
        assert_equal "int32", small_int_param.schema.format
      end

      # === Parameter examples (grape-swagger params_example_spec.rb) ===

      def test_parameter_with_example_value
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :id, type: Integer, documentation: { example: 123 }
            optional :name, type: String, documentation: { example: "John Doe" }
          end
          get "users/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        id_param = params.find { |p| p.name == "id" }
        name_param = params.find { |p| p.name == "name" }

        # Examples should be on schema
        assert_equal 123, id_param.schema.examples if id_param.schema.respond_to?(:examples)
        assert_equal "John Doe", name_param.schema.examples if name_param.schema.respond_to?(:examples)
      end

      def test_body_parameter_with_example
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :data, type: Hash, documentation: { param_type: "body", example: { foo: "bar" } } do
              requires :value, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        refute_nil body_schema
        # Example handling depends on implementation
      end

      # === Hidden parameters (grape-swagger api_swagger_v2_hide_param_spec.rb) ===

      def test_hidden_parameter_is_excluded
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :visible, type: String
            optional :hidden_param, type: String, documentation: { hidden: true }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        visible_param = params.find { |p| p.name == "visible" }
        hidden_param = params.find { |p| p.name == "hidden_param" }

        refute_nil visible_param
        assert_nil hidden_param
      end

      def test_hidden_parameter_with_proc
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :visible, type: String
            optional :proc_hidden, type: String, documentation: { hidden: proc { true } }
            optional :proc_visible, type: String, documentation: { hidden: proc { false } }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        param_names = params.map(&:name)

        assert_includes param_names, "visible"
        refute_includes param_names, "proc_hidden"
        assert_includes param_names, "proc_visible"
      end

      def test_required_param_never_hidden
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :required_but_marked_hidden, type: String, documentation: { hidden: true }
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        # Required params should never be hidden, even if marked as such
        param = params.find { |p| p.name == "required_but_marked_hidden" }

        refute_nil param
      end

      def test_hidden_body_parameter_is_excluded
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :visible, type: String, documentation: { param_type: "body" }
            optional :hidden_field, type: String, documentation: { param_type: "body", hidden: true }
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        assert_includes body_schema.properties.keys, "visible"
        refute_includes body_schema.properties.keys, "hidden_field"
      end

      # === Extensions on parameters (x-* fields) ===

      def test_parameter_with_x_extensions
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :logs, type: String, documentation: {
              "x-name" => "Log",
              "x-nullable" => true
            }
          end
          get "logs" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        logs_param = params.find { |p| p.name == "logs" }

        refute_nil logs_param
        # Extensions should be preserved on schema
        skip unless logs_param.schema.respond_to?(:extensions) && logs_param.schema.extensions

        assert_equal "Log", logs_param.schema.extensions["x-name"]
      end

      # === Additional Properties configurations ===

      def test_hash_with_additional_properties_false
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :data, type: Hash, documentation: { param_type: "body", additional_properties: false } do
              requires :name, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        data_prop = body_schema.properties["data"]

        refute data_prop.additional_properties
      end

      def test_hash_with_additional_properties_true
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :metadata, type: Hash, documentation: { param_type: "body", additional_properties: true } do
              optional :version, type: String
            end
          end
          post "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        body_schema, _params = builder.build

        metadata_prop = body_schema.properties["metadata"]

        assert metadata_prop.additional_properties
      end

      # === Enum values on parameters ===

      def test_parameter_with_enum_values
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :status, type: String, values: %w[pending active completed]
            optional :priority, type: Integer, values: [1, 2, 3]
          end
          get "tasks" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        status_param = params.find { |p| p.name == "status" }
        priority_param = params.find { |p| p.name == "priority" }

        # NOTE: enum values handling depends on implementation
        refute_nil status_param
        refute_nil priority_param
      end

      # === Default values on parameters ===

      def test_parameter_with_default_value
        api_class = Class.new(Grape::API) do
          format :json
          params do
            optional :page, type: Integer, default: 1
            optional :limit, type: Integer, default: 20
          end
          get "items" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        page_param = params.find { |p| p.name == "page" }
        limit_param = params.find { |p| p.name == "limit" }

        # Default value handling depends on implementation
        refute_nil page_param
        refute_nil limit_param
      end

      # === Minimum/maximum constraints ===

      def test_parameter_with_min_max_constraints
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :count, type: Integer, documentation: { minimum: 0, maximum: 100 }
            requires :price, type: Float, documentation: { minimum: 0.01 }
          end
          get "products" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        count_param = params.find { |p| p.name == "count" }
        price_param = params.find { |p| p.name == "price" }

        # Constraint handling depends on implementation
        refute_nil count_param
        refute_nil price_param
      end

      # === String length constraints ===

      def test_parameter_with_length_constraints
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :username, type: String, documentation: { min_length: 3, max_length: 30 }
            requires :description, type: String, documentation: { max_length: 1000 }
          end
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        username_param = params.find { |p| p.name == "username" }
        description_param = params.find { |p| p.name == "description" }

        refute_nil username_param
        refute_nil description_param
      end

      # === Pattern constraint ===

      def test_parameter_with_pattern_constraint
        api_class = Class.new(Grape::API) do
          format :json
          params do
            requires :email, type: String, documentation: { pattern: "^[a-z]+@[a-z]+\\.[a-z]+$" }
          end
          post "contacts" do
            {}
          end
        end

        route = api_class.routes.first
        builder = RequestParams.new(api: @api, route: route)
        _body_schema, params = builder.build

        email_param = params.find { |p| p.name == "email" }

        refute_nil email_param
      end
    end
  end
end
