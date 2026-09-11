# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class ExplicitQueryNestedParamsTest < Minitest::Test
    SCHEMA_TYPES = %i[oas2 oas3 oas31].freeze
    WRITE_METHODS = %i[post put patch].freeze

    def test_query_located_nested_hash_survives_on_write_methods
      WRITE_METHODS.each do |http_method|
        api = Class.new(Grape::API) do
          format :json
          params do
            optional :filter, type: Hash, documentation: { in: "query" } do
              optional :kind, type: String
            end
          end
          public_send(http_method, "items") { {} }
        end

        SCHEMA_TYPES.each do |version|
          spec = GrapeOAS.generate(app: api, schema_type: version)
          operation = spec.dig("paths", "/items", http_method.to_s)
          context = "#{http_method}, #{version}"

          OASValidator.validate!(spec)

          assert_nil body_schema(spec, operation, version), context

          kind = operation.fetch("parameters", []).find { |param| param["name"] == "filter[kind]" }

          refute_nil kind, "expected filter[kind] to be present as a query param (#{context})"
          assert_equal "query", kind["in"], context
        end
      end
    end

    def test_mixed_body_and_query_nested_hashes_stay_in_their_declared_locations
      api = Class.new(Grape::API) do
        format :json
        params do
          optional :filter, type: Hash, documentation: { in: "query" } do
            optional :kind, type: String
          end
          optional :payload, type: Hash do
            optional :name, type: String
          end
        end
        post "items" do
          {}
        end
      end

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items", "post")

        OASValidator.validate!(spec)

        body = body_schema(spec, operation, version)
        query_names = operation.fetch("parameters", [])
                               .select { |param| param["in"] == "query" }
                               .map { |param| param["name"] }

        assert_equal ["filter[kind]"], query_names, version.to_s
        assert_equal ["payload"], body.fetch("properties").keys, version.to_s
      end
    end

    def test_childless_hash_query_parameter_is_omitted_from_oas2
      api = Class.new(Grape::API) do
        format :json
        params do
          optional :filters, type: Hash
        end
        get "items" do
          {}
        end
      end

      spec = GrapeOAS.generate(app: api, schema_type: :oas2)

      OASValidator.validate!(spec)

      operation = spec.dig("paths", "/items", "get")

      assert_empty operation.fetch("parameters")
    end

    def test_array_of_hash_query_parameter_is_omitted_from_oas2
      api = Class.new(Grape::API) do
        format :json
        params do
          optional :rows, type: [Hash]
        end
        get "items" do
          {}
        end
      end

      spec = GrapeOAS.generate(app: api, schema_type: :oas2)

      OASValidator.validate!(spec)

      operation = spec.dig("paths", "/items", "get")

      assert_empty operation.fetch("parameters")
    end

    def test_childless_hash_query_parameter_is_unchanged_in_oas3
      api = Class.new(Grape::API) do
        format :json
        params do
          optional :filters, type: Hash
        end
        get "items" do
          {}
        end
      end

      %i[oas3 oas31].each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)

        OASValidator.validate!(spec)

        operation = spec.dig("paths", "/items", "get")
        filters = operation.fetch("parameters", []).find { |param| param["name"] == "filters" }

        refute_nil filters, version.to_s
        assert_equal "object", filters.dig("schema", "type"), version.to_s
      end
    end

    private

    def body_schema(spec, operation, version)
      schema = if version == :oas2
                 operation.fetch("parameters", []).find { |param| param["in"] == "body" }&.fetch("schema", nil)
               else
                 operation.dig("requestBody", "content", "application/json", "schema")
               end
      return unless schema
      return schema unless schema["$ref"]

      spec.dig(*schema["$ref"].delete_prefix("#/").split("/"))
    end
  end
end
