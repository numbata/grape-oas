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
          primitive_types = PRIMITIVE_MAPPINGS.keys + %w[object string boolean file json array number]
          is_primitive = type && primitive_types.include?(type)

          if is_primitive && param.location != "body"
            mapping = PRIMITIVE_MAPPINGS[type]
            result = {
              "name" => param.name,
              "in" => param.location,
              "required" => param.required,
              "description" => param.description,
              "type" => mapping ? mapping[:type] : type,
              "format" => format || (mapping ? mapping[:format] : nil)
            }
            apply_schema_constraints(result, param.schema)
            apply_collection_format(result, param, type)
            result.compact
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

        def apply_schema_constraints(result, schema)
          return unless schema

          result["minimum"] = schema.minimum if schema.respond_to?(:minimum) && !schema.minimum.nil?
          result["maximum"] = schema.maximum if schema.respond_to?(:maximum) && !schema.maximum.nil?
          result["exclusiveMinimum"] = schema.exclusive_minimum if schema.respond_to?(:exclusive_minimum) && schema.exclusive_minimum
          result["exclusiveMaximum"] = schema.exclusive_maximum if schema.respond_to?(:exclusive_maximum) && schema.exclusive_maximum
          result["minLength"] = schema.min_length if schema.respond_to?(:min_length) && !schema.min_length.nil?
          result["maxLength"] = schema.max_length if schema.respond_to?(:max_length) && !schema.max_length.nil?
          result["minItems"] = schema.min_items if schema.respond_to?(:min_items) && !schema.min_items.nil?
          result["maxItems"] = schema.max_items if schema.respond_to?(:max_items) && !schema.max_items.nil?
          result["pattern"] = schema.pattern if schema.respond_to?(:pattern) && schema.pattern
          result["enum"] = normalize_enum(schema.enum, result["type"]) if schema.respond_to?(:enum) && schema.enum
        end

        def normalize_enum(enum_vals, type)
          return nil unless enum_vals.is_a?(Array)

          coerced = enum_vals.map do |v|
            case type
            when Constants::SchemaTypes::INTEGER then v.to_i if v.respond_to?(:to_i)
            when Constants::SchemaTypes::NUMBER then v.to_f if v.respond_to?(:to_f)
            else v
            end
          end.compact

          result = coerced.uniq
          return nil if result.empty?

          result
        end

        def apply_collection_format(result, param, type)
          return unless type == Constants::SchemaTypes::ARRAY
          return unless param.collection_format

          valid_formats = %w[csv ssv tsv pipes multi brackets]
          result["collectionFormat"] = param.collection_format if valid_formats.include?(param.collection_format)
        end

        def build_body_parameter(request_body)
          schema = build_body_schema(request_body)
          name = derive_body_name(request_body)
          {
            "name" => name,
            "in" => "body",
            "required" => request_body.required,
            "description" => request_body.description,
            "schema" => schema
          }.compact
        end

        def derive_body_name(request_body)
          # Use explicit body_name if provided
          return request_body.body_name if request_body.respond_to?(:body_name) && request_body.body_name

          # Fall back to canonical name from schema
          canonical = begin
            request_body&.media_types&.first&.schema&.canonical_name
          rescue NoMethodError
            nil
          end
          canonical ? canonical.gsub("::", "_") : "body"
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
