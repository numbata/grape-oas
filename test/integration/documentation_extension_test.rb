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
end
