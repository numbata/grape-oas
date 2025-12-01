# frozen_string_literal: true

require "test_helper"
require "rack/mock"
require "json"

class DocumentationExtensionTest < Minitest::Test
  class DocAPI < Grape::API
    format :json

    desc "Ping"
    get "ping" do
      { ping: "pong" }
    end

    add_oas_documentation(
      host: "api.example.com",
      base_path: "/v1",
      schemes: ["https"],
      tags: [{ name: "users" }],
      security_definitions: {
        api_key: { type: "apiKey", name: "X-API-Key", in: "header" }
      },
      security: [{ api_key: [] }],
      info: { title: "Doc API", version: "2.0" },
    )
  end

  def test_oas2_output_from_mounted_endpoint
    resp = Rack::MockRequest.new(DocAPI).get("/swagger_doc.json?oas=2")

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "2.0", body["swagger"]
    assert_equal "api.example.com", body["host"]
    assert_equal "/v1", body["basePath"]
    assert_equal ["https"], body["schemes"]
    assert_equal "Doc API", body.dig("info", "title")
    assert body["securityDefinitions"].key?("api_key")
    assert_equal [{ "api_key" => [] }], body["security"]
  end

  def test_oas3_output_from_mounted_endpoint
    resp = Rack::MockRequest.new(DocAPI).get("/swagger_doc.json?oas=3")

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "3.0.0", body["openapi"]
    assert_equal "Doc API", body.dig("info", "title")
    server_url = body.dig("servers", 0, "url")

    assert_equal "https://api.example.com/v1", server_url
    assert body.dig("components", "securitySchemes", "api_key")
    assert_equal [{ "api_key" => [] }], body["security"]
  end

  class CustomMountPathAPI < Grape::API
    format :json

    desc "Hello endpoint"
    get "hello" do
      { message: "world" }
    end

    add_oas_documentation(
      oas_mount_path: "/oas_schema",
      security_definitions: {
        api_key: { type: "apiKey", name: "X-API-Key", in: "header" }
      },
      security: [{ api_key: [] }]
    )
  end

  def test_custom_mount_path_responds_with_oas_schema
    resp = Rack::MockRequest.new(CustomMountPathAPI).get("/oas_schema")

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    # Verify it's a valid OAS3 schema (default format)
    assert_equal "3.0.0", body["openapi"]

    # Verify security is included
    assert body.dig("components", "securitySchemes", "api_key")
    assert_equal [{ "api_key" => [] }], body["security"]

    # Verify the hello endpoint is documented
    assert body["paths"].key?("/hello")
  end

  def test_custom_mount_path_default_path_returns_404
    resp = Rack::MockRequest.new(CustomMountPathAPI).get("/swagger_doc.json")

    assert_equal 404, resp.status
  end

  def test_host_extracted_from_request_when_not_provided
    resp = Rack::MockRequest.new(CustomMountPathAPI).get(
      "/oas_schema?oas=2",
      "HTTP_HOST" => "dynamic.example.com"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "2.0", body["swagger"]
    assert_equal "dynamic.example.com", body["host"]
  end

  def test_explicit_host_takes_precedence_over_request_host
    resp = Rack::MockRequest.new(DocAPI).get(
      "/swagger_doc.json?oas=2",
      "HTTP_HOST" => "should-be-ignored.com"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    # Explicit host from add_oas_documentation should be used
    assert_equal "api.example.com", body["host"]
  end

  def test_host_includes_port_when_present
    resp = Rack::MockRequest.new(CustomMountPathAPI).get(
      "http://example.com:8080/oas_schema?oas=2"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "example.com:8080", body["host"]
  end

  def test_x_forwarded_host_takes_precedence
    resp = Rack::MockRequest.new(CustomMountPathAPI).get(
      "/oas_schema?oas=2",
      "HTTP_HOST" => "internal.example.com",
      "HTTP_X_FORWARDED_HOST" => "public.example.com"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    # X-Forwarded-Host should be used (like grape-swagger)
    assert_equal "public.example.com", body["host"]
  end

  # Proc/lambda support tests (like grape-swagger)
  class ProcHostAPI < Grape::API
    format :json

    desc "Test endpoint"
    get "test" do
      { ok: true }
    end

    add_oas_documentation(
      oas_mount_path: "/docs",
      host: ->(request) { request.host =~ /staging/ ? "staging-api.example.com" : "api.example.com" },
      base_path: ->(request) { request.path_info.start_with?("/v2") ? "/v2" : "/v1" }
    )
  end

  def test_proc_host_with_request_argument
    # Request to staging host
    resp = Rack::MockRequest.new(ProcHostAPI).get(
      "/docs?oas=2",
      "HTTP_HOST" => "staging.internal.com"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "staging-api.example.com", body["host"]
  end

  def test_proc_host_with_production_request
    # Request to production host
    resp = Rack::MockRequest.new(ProcHostAPI).get(
      "/docs?oas=2",
      "HTTP_HOST" => "production.internal.com"
    )

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "api.example.com", body["host"]
  end

  class LambdaNoArgAPI < Grape::API
    format :json

    get "ping" do
      { pong: true }
    end

    add_oas_documentation(
      oas_mount_path: "/schema",
      host: -> { "static-from-lambda.example.com" }
    )
  end

  def test_lambda_without_request_argument
    resp = Rack::MockRequest.new(LambdaNoArgAPI).get("/schema?oas=2")

    assert_equal 200, resp.status
    body = JSON.parse(resp.body)

    assert_equal "static-from-lambda.example.com", body["host"]
  end
end
