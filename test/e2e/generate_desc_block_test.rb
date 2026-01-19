# frozen_string_literal: true

require "test_helper"

class GenerateDescBlockTest < Minitest::Test
  class TestEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :name, documentation: { type: String }
  end

  class ErrorEntity < Grape::Entity
    expose :error, documentation: { type: String }
  end

  class DescBlockAPI < Grape::API
    format :json

    resource :users do
      desc "Get user with desc block" do
        success TestEntity
        failure [
          [400, "Bad Request", ErrorEntity],
          [404, "Not Found"]
        ]
      end
      get(":id") { nil }

      desc "Create user with desc block" do
        success({ code: 201, model: TestEntity, message: "Created" })
        failure({ code: 422, model: ErrorEntity, message: "Validation Error" })
      end
      post { nil }

      desc "Update user with entity" do
        entity TestEntity
      end
      put(":id") { nil }
    end
  end

  def test_desc_block_success_and_failure
    spec = spec_for
    responses = responses_for(spec, "/users/{id}", "get")

    assert responses["200"]
    assert_includes schema_ref(responses["200"]), "TestEntity"

    assert responses["400"]
    assert_equal "Bad Request", responses["400"]["description"]

    assert responses["404"]
    assert_equal "Not Found", responses["404"]["description"]
  end

  def test_desc_block_with_codes_and_messages
    spec = spec_for
    response_201 = response_for(spec, "/users", "post", 201)
    response_422 = response_for(spec, "/users", "post", 422)

    assert_equal "Created", response_201["description"]
    assert_equal "Validation Error", response_422["description"]
  end

  def test_desc_block_with_entity
    spec = spec_for
    response_200 = response_for(spec, "/users/{id}", "put", 200)

    assert response_200
    assert_includes schema_ref(response_200), "TestEntity"
  end

  private

  def spec_for
    GrapeOAS.generate(app: DescBlockAPI, schema_type: :oas3)
  end

  def responses_for(spec, path, verb)
    spec.dig("paths", path, verb, "responses")
  end

  def response_for(spec, path, verb, code)
    responses = responses_for(spec, path, verb)
    return nil unless responses

    responses[code.to_s]
  end

  def schema_ref(response)
    response.dig("content", "application/json", "schema", "$ref")
  end
end
