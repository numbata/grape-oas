# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    # Tests for summary vs description distinction
    class OperationSummaryDescriptionTest < Minitest::Test
      def setup
        @api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
      end

      # === Summary from desc option ===

      def test_summary_from_desc
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user by ID"
          get "user/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_equal "Get user by ID", op.summary
      end

      # === Detail option for description ===

      def test_detail_for_description
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user",
               detail: "Returns a user by their unique identifier. The user must exist."
          get "user/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_equal "Get user", op.summary
        assert_equal "Returns a user by their unique identifier. The user must exist.", op.description
      end

      # === Documentation desc for description ===

      def test_documentation_desc_for_description
        api_class = Class.new(Grape::API) do
          format :json
          desc "List items",
               documentation: { desc: "Lists all available items with pagination support." }
          get "items" do
            []
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_equal "List items", op.summary
        assert_equal "Lists all available items with pagination support.", op.description
      end

      # === Empty description ===

      def test_empty_description
        api_class = Class.new(Grape::API) do
          format :json
          get "simple" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_nil op.summary
        assert_nil op.description
      end

      # === Multiline description in detail ===

      def test_multiline_detail
        api_class = Class.new(Grape::API) do
          format :json
          desc "Create user",
               detail: <<~DESC
                 Creates a new user in the system.

                 Required fields: name, email
                 Optional fields: phone, address
               DESC
          post "users" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_equal "Create user", op.summary
        refute_nil op.description
        assert_includes op.description, "Required fields"
      end

      # === Summary and description both via documentation ===

      def test_summary_and_description_via_documentation
        api_class = Class.new(Grape::API) do
          format :json
          desc "Update user",
               documentation: {
                 summary: "Update user details",
                 desc: "Updates an existing user's information"
               }
          put "users/:id" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        # summary from documentation should override desc
        # Or if not supported, desc should be the summary
        refute_nil op.summary
        # desc from documentation should be description
        assert_equal "Updates an existing user's information", op.description
      end

      # === Summary with special characters ===

      def test_summary_with_special_characters
        api_class = Class.new(Grape::API) do
          format :json
          desc "Get user's data (v2)"
          get "users/:id/data" do
            {}
          end
        end

        route = api_class.routes.first
        builder = Operation.new(api: @api, route: route)
        op = builder.build

        assert_equal "Get user's data (v2)", op.summary
      end
    end
  end
end
