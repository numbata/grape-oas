# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateOAS3ContractEntityTest < Minitest::Test
    class BookEntity < Grape::Entity
      expose :id, documentation: { type: Integer, desc: "Book ID" }
      expose :title, documentation: { type: String }
    end

    class API < Grape::API
      format :json

      # Regular params endpoint
      namespace :books do
        desc "List books"
        params do
          optional :page, type: Integer, documentation: { param_type: "query" }
        end
        get do
          { items: [] }
        end
      end

      # Contract + entity endpoint
      namespace :admin do
        Contract = Dry::Schema.Params do
          required(:id).filled(:integer)
          optional(:status).maybe(:string, included_in?: %w[draft published])
        end

        desc "Update book", contract: Contract
        params do
          requires :id, type: Integer
          requires :payload, type: BookEntity, documentation: { param_type: "body" }
        end
        put "books/:id", entity: BookEntity do
          { id: params[:id], title: "Updated" }
        end
      end
    end

    def test_oas3_contains_params_contract_and_entity
      schema = GrapeOAS.generate(app: API, schema_type: :oas3)

      # Regular params in list endpoint
      list_params = schema["paths"]["/books"]["get"]["parameters"]
      page_param = list_params.find { |p| p["name"] == "page" }

      assert_equal "query", page_param["in"]
      assert_equal "integer", page_param["schema"]["type"]

      # Contract-driven requestBody in admin update (overrides params body)
      update_op = schema["paths"]["/admin/books/{id}"]["put"]
      request_body = update_op["requestBody"]

      assert request_body
      req_schema = request_body["content"]["application/json"]["schema"]
      if req_schema["$ref"]
        assert_includes req_schema["$ref"], "#/components/schemas"
      else
        assert_equal "object", req_schema["type"]
        assert_equal %w[id status].sort, req_schema["properties"].keys.sort
        status_prop = req_schema["properties"]["status"]

        assert_equal %w[draft published], status_prop["enum"]
        refute_includes req_schema["required"], "status"
      end

      # Response uses entity schema (object with title)
      response_schema = update_op["responses"]["200"]["content"]["application/json"]["schema"]
      if response_schema["$ref"]
        assert_includes response_schema["$ref"], "#/components/schemas"
      else
        assert_equal "object", response_schema["type"]
        assert_includes response_schema["properties"].keys, "title"
      end
    end
  end
end
