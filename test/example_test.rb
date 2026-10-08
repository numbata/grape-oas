# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "rack/test"
require_relative "../examples/api"

class ExampleTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CatalogAPI
  end

  def test_example_endpoint
    get "/books/42"

    assert_equal 200, last_response.status
    assert_equal({ "id" => 42, "title" => "The Ruby Programming Language" }, JSON.parse(last_response.body))
  end

  def test_documentation_endpoints_and_manual_generation
    { nil => ["oas3", "openapi", "3.0"], "2" => ["oas2", "swagger", "2.0"],
      "3.1" => ["oas31", "openapi", "3.1"] }.each do |query, (format, key, prefix)|
      get "/swagger_doc", query ? { oas: query } : {}

      assert_equal 200, last_response.status
      document = JSON.parse(last_response.body)

      assert document.fetch(key).start_with?(prefix)
      assert_equal ["/books/{id}"], document.fetch("paths").keys
      parameter = document.fetch("paths").fetch("/books/{id}").fetch("get").fetch("parameters").first

      assert_equal "path", parameter.fetch("in")
      assert_equal "id", parameter.fetch("name")
      assert parameter.fetch("required")
      assert_equal ["/books/{id}"], GrapeOAS.generate(app: CatalogAPI, schema_type: format.to_sym).fetch("paths").keys
    end
  end
end
