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
          context = "#{http_method}, #{version}, #{location_key}, nested=#{nested}"

          refute_nil body, context
          note = body.dig("properties", "note")
          note = note.dig("properties", "text") if nested

          assert_equal "string", note["type"], context
          non_body = operation.fetch("parameters", []).reject { |param| param["in"] == "body" }

          assert_equal([%w[id path]], non_body.map { |param| param.values_at("name", "in") }, context)
        end
      end
    end

    def test_unannotated_parameters_remain_in_query
      %i[get head delete].product(NESTING_OPTIONS).each do |http_method, nested|
        api = build_api(http_method: http_method, nested: nested)
        SCHEMA_TYPES.each do |version|
          spec = GrapeOAS.generate(app: api, schema_type: version)
          operation = spec.dig("paths", "/items/{id}", http_method.to_s)
          context = "#{http_method}, #{version}, nested=#{nested}"

          assert_nil body_schema(spec, operation, version), context
          name = nested ? "note[text]" : "note"
          note = operation.fetch("parameters").find { |param| param["name"] == name }

          assert_equal "query", note["in"], context
        end
      end
    end

    def test_path_annotation_does_not_enable_request_body
      api = Class.new(Grape::API) do
        format :json
        params do
          requires :id, type: Integer, documentation: { in: "body" }
          optional :filter, type: Hash do
            optional :kind, type: String
          end
        end
        get "items/:id" do
          {}
        end
      end

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items/{id}", "get")
        context = "path annotation, #{version}"

        assert_nil body_schema(spec, operation, version), context
        filter = operation.fetch("parameters").find { |param| param["name"] == "filter[kind]" }

        assert_equal "query", filter["in"], context
      end
    end

    def test_param_type_takes_precedence_over_in_for_body_opt_in
      api = build_api(documentation: { param_type: "query", in: "body" }, nested: true, http_method: :delete)

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items/{id}", "delete")
        context = "param_type precedence, #{version}"

        assert_nil body_schema(spec, operation, version), context
        note = operation.fetch("parameters").find { |param| param["name"] == "note[text]" }

        assert_equal "query", note["in"], context
      end
    end

    def test_hidden_body_annotation_does_not_enable_request_body
      api = Class.new(Grape::API) do
        format :json
        params do
          optional :hidden_note, type: String, documentation: { hidden: true, in: "body" }
          optional :filter, type: Hash do
            optional :kind, type: String
          end
        end
        get "items" do
          {}
        end
      end

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items", "get")
        context = "hidden annotation, #{version}"

        assert_nil body_schema(spec, operation, version), context
        filter = operation.fetch("parameters").find { |param| param["name"] == "filter[kind]" }

        assert_equal "query", filter["in"], context
      end
    end

    def test_body_name_enables_bodyless_request_body
      api = Class.new(Grape::API) do
        format :json
        desc "Search", body_name: "payload"
        params do
          optional :filter, type: String
        end
        get "items" do
          {}
        end
      end

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items", "get")
        body = body_schema(spec, operation, version)
        context = "body_name, #{version}"

        refute_nil body, context
        assert_equal "string", body.dig("properties", "filter", "type"), context
      end
    end

    def test_route_request_body_opt_in_handles_flat_parameters
      api = Class.new(Grape::API) do
        format :json
        desc "Search", documentation: { request_body: true }
        params do
          optional :filter, type: String
        end
        get "items" do
          {}
        end
      end

      SCHEMA_TYPES.each do |version|
        spec = GrapeOAS.generate(app: api, schema_type: version)
        operation = spec.dig("paths", "/items", "get")
        body = body_schema(spec, operation, version)

        refute_nil body, "route request_body, #{version}"
        assert_equal "string", body.dig("properties", "filter", "type"), "route request_body, #{version}"
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
