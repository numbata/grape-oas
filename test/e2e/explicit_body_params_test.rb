# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class ExplicitBodyParamsTest < Minitest::Test
    SCHEMA_TYPES = %i[oas2 oas3 oas31].freeze
    NESTING_OPTIONS = [false, true].freeze

    def test_explicit_body_parameters_survive_all_exporters
      %i[get head delete].product(%i[param_type in], NESTING_OPTIONS).each do |http_method, location_key, nested|
        api = build_api(documentation: { location_key => "body" }, nested: nested, http_method: http_method)
        SCHEMA_TYPES.each do |version|
          spec = GrapeOAS.generate(app: api, schema_type: version)
          operation = spec.dig("paths", "/items/{id}", http_method.to_s)
          body = body_schema(spec, operation, version)

          refute_nil body, "#{http_method}, #{version}, #{location_key}, nested=#{nested}"
          note = body.dig("properties", "note")
          note = note.dig("properties", "text") if nested

          assert_equal "string", note["type"]
          non_body = operation.fetch("parameters", []).reject { |param| param["in"] == "body" }

          assert_equal([%w[id path]], non_body.map { |param| param.values_at("name", "in") })
        end
      end
    end

    def test_unannotated_parameters_remain_in_query
      %i[get head delete].product(NESTING_OPTIONS).each do |http_method, nested|
        api = build_api(http_method: http_method, nested: nested)
        SCHEMA_TYPES.each do |version|
          spec = GrapeOAS.generate(app: api, schema_type: version)
          operation = spec.dig("paths", "/items/{id}", http_method.to_s)

          assert_nil body_schema(spec, operation, version)
          name = nested ? "note[text]" : "note"
          note = operation.fetch("parameters").find { |param| param["name"] == name }

          assert_equal "query", note["in"]
        end
      end
    end

    private

    def build_api(documentation: {}, nested: false, http_method: :delete)
      Class.new(Grape::API) do
        format :json
        params do
          requires :id, type: Integer
          if nested
            optional :note, type: Hash, documentation: documentation do
              optional :text, type: String
            end
          else
            optional :note, type: String, documentation: documentation
          end
        end
        public_send(http_method, "items/:id") { {} }
      end
    end

    def body_schema(spec, operation, version)
      schema = if version == :oas2
                 operation.fetch("parameters", []).find { |param| param["in"] == "body" }&.fetch("schema")
               else
                 operation.dig("requestBody", "content", "application/json", "schema")
               end
      return unless schema
      return schema unless schema["$ref"]

      spec.dig(*schema["$ref"].delete_prefix("#/").split("/"))
    end
  end
end
