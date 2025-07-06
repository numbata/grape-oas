# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS2Schema
      def initialize(api_model:)
        @api = api_model
        @ref_tracker = Set.new
      end

      def generate
        {
          "swagger" => "2.0",
          "info" => build_info,
          "host" => build_host,
          "basePath" => build_base_path,
          "schemes" => build_schemes,
          "consumes" => build_consumes,
          "produces" => build_produces,
          "tags" => build_tags,
          "paths" => build_paths,
          "definitions" => build_definitions
          # TODO: Add securityDefinitions, externalDocs, parameters, responses, etc.
        }.compact
      end

      private

      def build_info
        {
          "title" => @api.title,
          "version" => @api.version
        }
      end

      def build_host
        # TODO: Derive from servers if possible
        nil
      end

      def build_base_path
        # TODO: Derive from servers if possible
        nil
      end

      def build_schemes
        # TODO: Derive from servers if possible
        nil
      end

      def build_consumes
        # TODO: Derive from request bodies/media types
        ["application/json"]
      end

      def build_produces
        # TODO: Derive from responses/media types
        ["application/json"]
      end

      def build_tags
        Array(@api.tag_defs).map do |tag|
          # TODO: Add tag builder here
          tag.is_a?(Hash) ? tag : { "name" => tag.to_s }
        end
      end

      def build_paths
        OAS2::Paths.new(@api, @ref_tracker).build
      end

      def build_schema_or_ref(schema)
        if schema.respond_to?(:canonical_name) && schema.canonical_name
          ref_name = schema.canonical_name.gsub("::", "_")
          @ref_tracker << schema.canonical_name
          { "$ref" => "#/definitions/#{ref_name}" }
        else
          build_schema(schema)
        end
      end

      def build_schema(schema)
        OAS2::Schema.new(schema, @ref_tracker).build
      end

      def build_definitions
        definitions = {}
        @ref_tracker.each do |canonical_name|
          ref_name = canonical_name.gsub("::", "_")
          # Find the schema in the API (search all params, request bodies, responses)
          schema = find_schema_by_canonical_name(canonical_name)
          definitions[ref_name] = OAS2::Schema.new(schema, @ref_tracker).build if schema
        end
        definitions
      end

      def find_schema_by_canonical_name(canonical_name)
        @api.paths.each do |path|
          path.operations.each do |op|
            Array(op.parameters).each do |param|
              schema = param.schema
              return schema if schema.respond_to?(:canonical_name) && schema.canonical_name == canonical_name
            end
            if op.request_body
              Array(op.request_body.media_types).each do |mt|
                schema = mt.schema
                return schema if schema.respond_to?(:canonical_name) && schema.canonical_name == canonical_name
              end
            end
            Array(op.responses).each do |resp|
              Array(resp.media_types).each do |mt|
                schema = mt.schema
                return schema if schema.respond_to?(:canonical_name) && schema.canonical_name == canonical_name
              end
            end
          end
        end
        nil
      end
    end
  end
end
