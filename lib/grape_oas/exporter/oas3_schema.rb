# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS3Schema
      def initialize(api_model:)
        @api = api_model
        @ref_tracker = Set.new
        @ref_schemas = {}
      end

      def generate
        {
          "openapi" => openapi_version,
          "info" => build_info,
          "servers" => build_servers,
          "tags" => build_tags,
          "paths" => OAS3::Paths.new(@api, @ref_tracker, nullable_keyword: nullable_keyword?).build,
          "components" => build_components,
          "security" => build_security
        }.compact
      end

      private

      def openapi_version
        "3.0.0"
      end

      # Allow subclasses (e.g., OAS31Schema) to override
      def schema_builder
        OAS3::Schema
      end

      def build_info
        info = {
          "title" => @api.title,
          "version" => @api.version
        }
        license = if @api.respond_to?(:license) && @api.license
                    @api.license.dup
                  else
                    { "name" => "Proprietary", "url" => "https://grape.local/license" }
                  end
        license.delete("identifier")
        license["url"] ||= "https://grape.local/license"
        info["license"] = license
        info
      end

      def build_servers
        servers = Array(@api.servers).map do |srv|
          srv.is_a?(Hash) ? srv : { "url" => srv.to_s }
        end

        servers = [{ "url" => "https://api.grape.local" }] if servers.empty?

        servers
      end

      def build_tags
        tags = Array(@api.tag_defs).map do |tag|
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
        tags.empty? ? nil : tags
      end

      def build_components
        schemas = build_schemas
        security_schemes = build_security_schemes
        components = {}
        components["schemas"] = schemas if schemas.any?
        components["securitySchemes"] = security_schemes if security_schemes&.any?
        components
      end

      def build_schemas
        schemas = {}
        pending = @ref_tracker ? @ref_tracker.to_a : []
        processed = Set.new

        until pending.empty?
          canonical_name = pending.shift
          next if processed.include?(canonical_name)

          processed << canonical_name

          ref_name = canonical_name.gsub("::", "_")
          schema = find_schema_by_canonical_name(canonical_name)
          if schema
            schemas[ref_name] =
              OAS3::Schema.new(schema, @ref_tracker, nullable_keyword: nullable_keyword?).build
          end
          collect_refs(schema, pending) if schema

          # any new refs added while building
          next unless @ref_tracker

          @ref_tracker.to_a.each do |cn|
            pending << cn unless processed.include?(cn) || pending.include?(cn)
          end
        end

        schemas
      end

      def build_security_schemes
        return nil if @api.security_definitions.nil? || @api.security_definitions.empty?

        @api.security_definitions
      end

      def build_security
        return @api.security unless @api.security.nil? || @api.security.empty?

        []
      end

      def nullable_keyword?
        true
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
