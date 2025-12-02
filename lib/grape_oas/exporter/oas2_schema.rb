# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS2Schema
      def initialize(api_model:)
        @api = api_model
        @ref_tracker = Set.new
        @ref_schemas = {}
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
          "definitions" => build_definitions,
          "securityDefinitions" => build_security_definitions,
          "security" => build_security
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
        @api.host
      end

      def build_base_path
        @api.base_path
      end

      def build_schemes
        Array(@api.schemes).presence
      end

      def build_consumes
        # TODO: Derive from request bodies/media types
        [Constants::MimeTypes::JSON]
      end

      def build_produces
        # TODO: Derive from responses/media types
        [Constants::MimeTypes::JSON]
      end

      def build_tags
        Array(@api.tag_defs).map do |tag|
          if tag.is_a?(Hash)
            tag
          elsif tag.respond_to?(:name)
            h = { "name" => tag.name.to_s }
            h["description"] = tag.description if tag.respond_to?(:description)
            h
          else
            name = tag.to_s
            desc = if defined?(ActiveSupport::Inflector)
                     "Operations about #{ActiveSupport::Inflector.pluralize(name)}"
                   else
                     "Operations about #{name}s"
                   end
            { "name" => name, "description" => desc }
          end
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
        pending = @ref_tracker.to_a
        processed = Set.new

        until pending.empty?
          canonical_name = pending.shift
          next if processed.include?(canonical_name)

          processed << canonical_name

          ref_name = canonical_name.gsub("::", "_")
          schema = find_schema_by_canonical_name(canonical_name)
          definitions[ref_name] = OAS2::Schema.new(schema, @ref_tracker).build if schema
          collect_refs(schema, pending) if schema

          @ref_tracker.to_a.each do |cn|
            pending << cn unless processed.include?(cn) || pending.include?(cn)
          end
        end

        definitions
      end

      def build_security_definitions
        return nil if @api.security_definitions.nil? || @api.security_definitions.empty?

        @api.security_definitions
      end

      def build_security
        return nil if @api.security.nil? || @api.security.empty?

        @api.security
      end

      def find_schema_by_canonical_name(canonical_name)
        return @ref_schemas[canonical_name] if @ref_schemas.key?(canonical_name)

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

      def collect_refs(schema, pending, seen = Set.new)
        return unless schema

        # short-circuit already visited schemas to avoid infinite recursion on self references
        if schema.respond_to?(:canonical_name) && schema.canonical_name
          return if seen.include?(schema.canonical_name)

          seen << schema.canonical_name
          @ref_schemas[schema.canonical_name] ||= schema
        end

        if schema.respond_to?(:properties) && schema.properties
          schema.properties.each_value do |prop|
            if prop.respond_to?(:canonical_name) && prop.canonical_name
              pending << prop.canonical_name
              @ref_schemas[prop.canonical_name] ||= prop
            end
            collect_refs(prop, pending, seen)
          end
        end
        collect_refs(schema.items, pending, seen) if schema.respond_to?(:items) && schema.items
      end
    end
  end
end
