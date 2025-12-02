# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      class Parameter
        PRIMITIVE_MAPPINGS = {
          Constants::SchemaTypes::INTEGER => { type: Constants::SchemaTypes::INTEGER, format: "int32" },
          "long" => { type: Constants::SchemaTypes::INTEGER, format: "int64" },
          "float" => { type: Constants::SchemaTypes::NUMBER, format: "float" },
          "double" => { type: Constants::SchemaTypes::NUMBER, format: "double" },
          "byte" => { type: Constants::SchemaTypes::STRING, format: "byte" },
          "date" => { type: Constants::SchemaTypes::STRING, format: "date" },
          "dateTime" => { type: Constants::SchemaTypes::STRING, format: "date-time" },
          "binary" => { type: Constants::SchemaTypes::STRING, format: "binary" },
          "password" => { type: Constants::SchemaTypes::STRING, format: "password" },
          "email" => { type: Constants::SchemaTypes::STRING, format: "email" },
          "uuid" => { type: Constants::SchemaTypes::STRING, format: "uuid" }
        }.freeze

        def initialize(operation, ref_tracker = nil)
          @op = operation
          @ref_tracker = ref_tracker
        end

        def build
          params = Array(@op.parameters).map { |param| build_parameter(param) }
          params << build_body_parameter(@op.request_body) if @op.request_body
          params
        end

        private

        def build_parameter(param)
          type = param.schema&.type
          format = param.schema&.format
          primitive_types = PRIMITIVE_MAPPINGS.keys + %w[object string boolean file json array]
          is_primitive = type && primitive_types.include?(type)

          if is_primitive && param.location != "body"
            mapping = PRIMITIVE_MAPPINGS[type]
            {
              "name" => param.name,
              "in" => param.location,
              "required" => param.required,
              "description" => param.description,
              "type" => mapping ? mapping[:type] : type,
              "format" => format || (mapping ? mapping[:format] : nil)
            }.compact
          else
            {
              "name" => param.name,
              "in" => param.location,
              "required" => param.required,
              "description" => param.description,
              "schema" => build_schema_or_ref(param.schema)
            }.tap do |h|
              h["type"] = type if type
              h["format"] = format if format
            end.compact
          end
        end

        def build_body_parameter(request_body)
          schema = build_body_schema(request_body)
          canonical = begin
            request_body&.media_types&.first&.schema&.canonical_name
          rescue NoMethodError
            nil
          end
          name = canonical ? canonical.gsub("::", "_") : "body"
          {
            "name" => name,
            "in" => "body",
            "required" => request_body.required,
            "description" => request_body.description,
            "schema" => schema
          }.compact
        end

        def build_body_schema(request_body)
          mt = Array(request_body.media_types).first
          mt ? build_schema_or_ref(mt.schema) : nil
        end

        def build_schema_or_ref(schema)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            { "$ref" => "#/definitions/#{ref_name}" }
          else
            Schema.new(schema, @ref_tracker).build
          end
        end
      end
    end
  end
end
