# frozen_string_literal: true

require "test_helper"

class DescBlockComprehensiveTest < Minitest::Test
  class TestEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :name, documentation: { type: String }
  end

  class ErrorEntity < Grape::Entity
    expose :error, documentation: { type: String }
  end

  class PlainModel
    def self.name
      "PlainModel"
    end
  end

  def test_success_with_grape_entity_simple
    spec = build_spec do
      desc "Test" do
        success TestEntity
      end
      get { nil }
    end
    response_200 = response_for(spec)

    assert response_200
    assert_includes schema_ref(response_200), "TestEntity"
  end

  def test_success_with_plain_model_simple
    spec = build_spec do
      desc "Test" do
        success PlainModel
      end
      get { nil }
    end
    response_200 = response_for(spec)

    assert response_200
  end

  def test_success_with_hash_syntax_grape_entity
    spec = build_spec do
      desc "Test" do
        success({ model: TestEntity })
      end
      get { nil }
    end
    response_200 = response_for(spec)

    assert response_200
    assert_includes schema_ref(response_200), "TestEntity"
  end

  def test_success_with_hash_syntax_code_and_message
    spec = build_spec do
      desc "Test" do
        success({ code: 201, model: TestEntity, message: "Created" })
      end
      get { nil }
    end
    response_201 = response_for(spec, code: 201)

    assert response_201
    assert_equal "Created", response_201["description"]
    assert_includes schema_ref(response_201), "TestEntity"
  end

  def test_failure_array_syntax_code_message
    spec = build_spec do
      desc "Test" do
        failure [404, "Not Found"]
      end
      get { nil }
    end
    response_404 = response_for(spec, code: 404)

    assert response_404
    assert_equal "Not Found", response_404["description"]
  end

  def test_failure_array_syntax_code_message_entity
    spec = build_spec do
      desc "Test" do
        failure [400, "Bad Request", ErrorEntity]
      end
      get { nil }
    end
    response_400 = response_for(spec, code: 400)

    assert response_400
    assert_equal "Bad Request", response_400["description"]
    assert_includes schema_ref(response_400), "ErrorEntity"
  end

  def test_failure_hash_syntax
    spec = build_spec do
      desc "Test" do
        failure({ code: 422, model: ErrorEntity, message: "Validation Error" })
      end
      get { nil }
    end
    response_422 = response_for(spec, code: 422)

    assert response_422
    assert_equal "Validation Error", response_422["description"]
    assert_includes schema_ref(response_422), "ErrorEntity"
  end

  def test_entity_syntax
    spec = build_spec do
      desc "Test" do
        entity TestEntity
      end
      get { nil }
    end
    response_200 = response_for(spec)

    assert response_200
    assert_includes schema_ref(response_200), "TestEntity"
  end

  def test_multiple_failures_mixed_syntax
    spec = build_spec do
      desc "Test" do
        success TestEntity
        failure({ code: 422, model: ErrorEntity, message: "Validation Error" })
      end
      get { nil }
    end
    responses = responses_for(spec)

    assert responses["200"]
    assert_includes schema_ref(responses["200"]), "TestEntity"

    assert responses["422"]
    assert_equal "Validation Error", responses["422"]["description"]
    assert_includes schema_ref(responses["422"]), "ErrorEntity"
  end

  def test_hash_style
    spec = build_spec do
      desc "Test" do
        success({
                  code: 201,
                  message: "Created successfully",
                  model: TestEntity
                })
        failure({
                  code: 400,
                  message: "Bad Request",
                  model: ErrorEntity
                })
      end
      post { nil }
    end
    responses = responses_for(spec, verb: "post")

    assert responses["201"]
    assert_equal "Created successfully", responses["201"]["description"]
    assert_includes schema_ref(responses["201"]), "TestEntity"

    assert responses["400"]
    assert_equal "Bad Request", responses["400"]["description"]
    assert_includes schema_ref(responses["400"]), "ErrorEntity"
  end

  private

  def build_spec(&block)
    api_class = Class.new(Grape::API) do
      format :json
      resource :test do
        instance_eval(&block)
      end
    end

    GrapeOAS.generate(app: api_class, schema_type: :oas3)
  end

  def responses_for(spec, path: "/test", verb: "get")
    spec.dig("paths", path, verb, "responses")
  end

  def response_for(spec, path: "/test", verb: "get", code: 200)
    responses = responses_for(spec, path: path, verb: verb)
    return nil unless responses

    responses[code.to_s]
  end

  def schema_ref(response)
    response.dig("content", "application/json", "schema", "$ref")
  end
end
