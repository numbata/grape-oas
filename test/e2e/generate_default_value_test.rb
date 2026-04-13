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
      assert_equal false, enabled_param["default"]
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
      assert_equal false, enabled_param["schema"]["default"]
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
  end
end
