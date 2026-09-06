# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsConditionalTest < Minitest::Test
      class NestedAPI < Grape::API
        params do
          requires :address, type: String
          optional :delivery, type: Hash do
            optional :channel, type: String
            given :channel do
              requires :address, type: String
              requires :contact, type: Hash do
                requires :name, type: String
              end
            end
          end
        end
        route(%i[post get], "/nested") { {} }
      end

      class SeparateScopesAPI < Grape::API
        params do
          optional :channel, type: String
          given :channel do
            requires :address, type: String
          end
          requires :billing, type: Hash do
            requires :address, type: String
          end
        end
        post("/separate") { {} }
      end

      def test_nested_given_uses_full_names_and_inherited_dependencies
        body, = build_params(NestedAPI, "POST")
        delivery = body.properties.fetch("delivery")
        contact = delivery.properties.fetch("contact")

        assert_includes body.required, "address"
        refute_includes delivery.required, "address"
        refute_includes delivery.required, "contact"
        refute_includes contact.required, "name"
      end

      def test_nested_query_requirements_follow_given_scopes
        _, params = build_params(NestedAPI, "GET")
        by_name = params.to_h { |param| [param.name, param] }

        assert by_name.fetch("address").required
        refute by_name.fetch("delivery[address]").required
        refute by_name.fetch("delivery[contact][name]").required
      end

      def test_unconditional_requirement_in_different_scope_does_not_override_given
        body, = build_params(SeparateScopesAPI, "POST")

        refute_includes body.required, "address"
        assert_includes body.properties.fetch("billing").required, "address"
      end

      private

      def build_params(app, method)
        route = app.routes.find { |candidate| candidate.request_method == method }
        api = ApiModel::API.new(title: "Test", version: "1")
        RequestParams.new(api: api, route: route).build
      end
    end
  end
end
