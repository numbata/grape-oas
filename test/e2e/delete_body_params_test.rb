# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class DeleteBodyParamsTest < Minitest::Test
    SCHEMA_TYPES = %i[oas2 oas3 oas31].freeze
    NESTING_OPTIONS = [false, true].freeze

    def test_explicit_body_parameters_survive_all_exporters
      %i[param_type in].each do |location_key|
        NESTING_OPTIONS.each do |nested|
          api = build_api(documentation: { location_key => "body" }, nested: nested)
          SCHEMA_TYPES.each do |version|
            spec = GrapeOAS.generate(app: api, schema_type: version)
            operation = spec.dig("paths", "/items/{id}", "delete")
            body = body_schema(spec, operation, version)

            refute_nil body, "#{version}, #{location_key}, nested=#{nested}"
            note = body.dig("properties", "note")
            note = note.dig("properties", "text") if nested

            assert_equal "string", note["type"]
            non_body = operation.fetch("parameters", []).reject { |param| param["in"] == "body" }

            assert_equal([%w[id path]], non_body.map { |param| param.values_at("name", "in") })
          end
        end
      end
    end

    def test_unannotated_delete_parameters_remain_in_query
      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: build_api, schema_type: version)
        operation = spec.dig("paths", "/items/{id}", "delete")

        assert_nil body_schema(spec, operation, version)
        note = operation.fetch("parameters").find { |param| param["name"] == "note" }

        assert_equal "query", note["in"]
      end
    end

    def test_get_and_head_still_require_route_level_opt_in
      %i[get head].each do |http_method|
        api = build_api(documentation: { in: "body" }, http_method: http_method)
        SCHEMA_TYPES.each do |version|
          spec = GrapeOAS.generate(app: api, schema_type: version)
          operation = spec.dig("paths", "/items/{id}", http_method.to_s)

          assert_nil body_schema(spec, operation, version)
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
