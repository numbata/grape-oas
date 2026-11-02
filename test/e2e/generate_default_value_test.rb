# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  # Verifies we carry through default values to all OAS versions.
  class GenerateDefaultValueTest < Minitest::Test
    # === OAS2 ===

    def test_oas2_string_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :status, type: String, default: "pending"
        end
        get "items" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas2)
      parameters = schema["paths"]["/items"]["get"]["parameters"]
      status_param = parameters.find { |p| p["name"] == "status" }

      assert_equal "pending", status_param["default"]
    end

    def test_oas2_integer_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :page, type: Integer, default: 1
        end
        get "items" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas2)
      parameters = schema["paths"]["/items"]["get"]["parameters"]
      page_param = parameters.find { |p| p["name"] == "page" }

      assert_equal 1, page_param["default"]
    end

    def test_oas2_boolean_param_with_false_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :enabled, type: Grape::API::Boolean, default: false
        end
        get "settings" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas2)
      parameters = schema["paths"]["/settings"]["get"]["parameters"]
      enabled_param = parameters.find { |p| p["name"] == "enabled" }

      # false is a valid default — it must be present (not absent/nil)
      assert enabled_param.key?("default"), "expected 'default' key to be present"
      assert_equal false, enabled_param["default"] # rubocop:disable Minitest/RefuteFalse
    end

    def test_oas2_param_with_default_and_enum_exports_both
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :role, type: String, values: %w[admin user guest], default: "user"
        end
        get "accounts" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas2)
      parameters = schema["paths"]["/accounts"]["get"]["parameters"]
      role_param = parameters.find { |p| p["name"] == "role" }

      assert_equal %w[admin user guest], role_param["enum"]
      assert_equal "user", role_param["default"]
    end

    def test_oas2_body_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :name, type: String, default: "anonymous", documentation: { param_type: "body" }
          optional :retries, type: Integer, default: 3, documentation: { param_type: "body" }
        end
        post "users" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas2)
      properties = schema["definitions"]["post_users_Request"]["properties"]

      assert_equal "anonymous", properties["name"]["default"]
      assert_equal 3, properties["retries"]["default"]
    end

    # === OAS3 ===

    def test_oas3_string_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :status, type: String, default: "pending"
        end
        get "items" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas3)
      parameters = schema["paths"]["/items"]["get"]["parameters"]
      status_param = parameters.find { |p| p["name"] == "status" }

      assert_equal "pending", status_param["schema"]["default"]
    end

    def test_oas3_integer_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :page, type: Integer, default: 1
        end
        get "items" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas3)
      parameters = schema["paths"]["/items"]["get"]["parameters"]
      page_param = parameters.find { |p| p["name"] == "page" }

      assert_equal 1, page_param["schema"]["default"]
    end

    def test_oas3_boolean_param_with_false_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :enabled, type: Grape::API::Boolean, default: false
        end
        get "settings" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas3)
      parameters = schema["paths"]["/settings"]["get"]["parameters"]
      enabled_param = parameters.find { |p| p["name"] == "enabled" }

      # false is a valid default — it must be present (not absent/nil)
      assert enabled_param["schema"].key?("default"), "expected 'default' key to be present in schema"
      assert_equal false, enabled_param["schema"]["default"] # rubocop:disable Minitest/RefuteFalse
    end

    def test_oas3_param_with_default_and_enum_exports_both
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :role, type: String, values: %w[admin user guest], default: "user"
        end
        get "accounts" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas3)
      parameters = schema["paths"]["/accounts"]["get"]["parameters"]
      role_param = parameters.find { |p| p["name"] == "role" }

      assert_equal %w[admin user guest], role_param["schema"]["enum"]
      assert_equal "user", role_param["schema"]["default"]
    end

    def test_oas3_body_param_with_default_exports_default
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :name, type: String, default: "anonymous", documentation: { param_type: "body" }
          optional :retries, type: Integer, default: 3, documentation: { param_type: "body" }
        end
        post "users" do
          {}
        end
      end

      schema = GrapeOAS.generate(app: api_class, schema_type: :oas3)
      properties = schema["components"]["schemas"]["post_users_Request"]["properties"]

      assert_equal "anonymous", properties["name"]["default"]
      assert_equal 3, properties["retries"]["default"]
    end

    # === Callable defaults (all OAS versions) ===

    def test_callable_query_param_default_not_exported
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :limit, type: Integer, default: -> { 25 }
        end
        get "items" do
          {}
        end
      end

      %i[oas2 oas3 oas31].each do |schema_type|
        schema = GrapeOAS.generate(app: api_class, schema_type: schema_type)
        param = schema["paths"]["/items"]["get"]["parameters"].find { |p| p["name"] == "limit" }

        refute_nil param, schema_type
        refute param.key?("default"), "#{schema_type} emits a default for a callable"
        refute param.fetch("schema", {}).key?("default"), "#{schema_type} emits a default for a callable"
      end
    end

    def test_callable_body_param_default_not_exported
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :name, type: String, default: -> { "anonymous" }
        end
        post "items" do
          {}
        end
      end

      %i[oas2 oas3 oas31].each do |schema_type|
        name = request_properties(api_class, schema_type)["name"]

        refute_nil name, schema_type
        refute name.key?("default"), "#{schema_type} emits a default for a callable"
      end
    end

    def test_callable_nested_hash_child_default_not_exported
      api_class = Class.new(Grape::API) do
        format :json
        params do
          optional :filter, type: Hash do
            optional :page, type: Integer, default: -> { 1 }
          end
        end
        post "items" do
          {}
        end
      end

      %i[oas2 oas3 oas31].each do |schema_type|
        page = request_properties(api_class, schema_type).dig("filter", "properties", "page")

        refute_nil page, schema_type
        refute page.key?("default"), "#{schema_type} emits a default for a callable"
      end
    end

    private

    def request_properties(api_class, schema_type)
      schema = GrapeOAS.generate(app: api_class, schema_type: schema_type)
      definitions = schema_type == :oas2 ? schema["definitions"] : schema["components"]["schemas"]
      definitions["post_items_Request"]["properties"]
    end
  end
end
