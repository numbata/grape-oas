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

      def build_info
        {
          "title" => @api.title,
          "version" => @api.version
        }
      end

      def build_servers
        Array(@api.servers).map do |srv|
          srv.is_a?(Hash) ? srv : { "url" => srv.to_s }
        end.then { |arr| arr.empty? ? nil : arr }
      end

      def build_tags
        tags = Array(@api.tag_defs).map { |tag| tag.is_a?(Hash) ? tag : { "name" => tag.to_s } }
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
        return nil if @api.security.nil? || @api.security.empty?

        @api.security
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

      def collect_refs(schema, pending)
        return unless schema

        @ref_schemas[schema.canonical_name] ||= schema if schema.respond_to?(:canonical_name) && schema.canonical_name
        if schema.respond_to?(:properties) && schema.properties
          schema.properties.each_value do |prop|
            if prop.respond_to?(:canonical_name) && prop.canonical_name
              pending << prop.canonical_name
              @ref_schemas[prop.canonical_name] ||= prop
            end
            collect_refs(prop, pending)
          end
        end
        collect_refs(schema.items, pending) if schema.respond_to?(:items) && schema.items
      end
    end
  end
end
