# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class GenerateIntegerFormatTest < Minitest::Test
    class EventEntity < Grape::Entity
      expose :timestamp_ms, documentation: { type: "integer" }
      expose :explicit_timestamp_ms, documentation: { type: "integer", format: "int64" }
    end

    class EventAPI < Grape::API
      format :json
      desc "Echo a timestamp", success: EventEntity
      params do
        requires :timestamp_ms, type: Integer
        requires :small, type: Integer, documentation: { format: "int32" }
      end
      post("/events") { {} }
    end

    def test_generic_integer_has_no_format_and_explicit_widths_preserved
      %i[oas2 oas3 oas31].each do |dialect|
        spec = GrapeOAS.generate(app: EventAPI, schema_type: dialect)
        schemas = spec["definitions"] || spec.dig("components", "schemas")
        entity = schemas.fetch(schemas.keys.grep(/EventEntity/).first)
        props = entity.fetch("properties")

        assert_equal "integer", props.fetch("timestamp_ms").fetch("type"), dialect.to_s
        refute props.fetch("timestamp_ms").key?("format"), "#{dialect}: generic integer must not infer a format"
        assert_equal "int64", props.fetch("explicit_timestamp_ms").fetch("format"), dialect.to_s
      end
    end

    def test_generic_integer_param_has_no_format_but_explicit_int32_preserved
      %i[oas2 oas3 oas31].each do |dialect|
        spec = GrapeOAS.generate(app: EventAPI, schema_type: dialect)
        schemas = spec["definitions"] || spec.dig("components", "schemas")
        props = schemas.fetch("post_events_Request").fetch("properties")

        refute props.fetch("timestamp_ms").key?("format"), "#{dialect}: generic integer param must not infer a format"
        assert_equal "int32", props.fetch("small").fetch("format"), dialect.to_s
      end
    end
  end
end
