# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS3Schema
      include Concerns::TagBuilder
      include Concerns::SchemaIndexer

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
          "paths" => OAS3::Paths.new(@api, @ref_tracker,
                                     nullable_keyword: nullable_keyword?,
                                     suppress_default_error_response: @api.suppress_default_error_response,).build,
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
                    { "name" => Constants::Defaults::LICENSE_NAME, "url" => Constants::Defaults::LICENSE_URL }
                  end
        license.delete("identifier")
        license["url"] ||= Constants::Defaults::LICENSE_URL
        info["license"] = license
        info
      end

      def build_servers
        servers = Array(@api.servers).map do |srv|
          srv.is_a?(Hash) ? srv : { "url" => srv.to_s }
        end

        servers = [{ "url" => Constants::Defaults::SERVER_URL }] if servers.empty?

        servers
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

        # Add pre-registered models to pending
        Array(@api.registered_schemas).each do |schema|
          pending << schema.canonical_name if schema.respond_to?(:canonical_name) && schema.canonical_name
        end

        until pending.empty?
          canonical_name = pending.shift
          next if processed.include?(canonical_name)

          processed << canonical_name

          ref_name = canonical_name.gsub("::", "_")
          schema = find_schema_by_canonical_name(canonical_name)
          if schema
            schemas[ref_name] =
              schema_builder.new(schema, @ref_tracker, nullable_keyword: nullable_keyword?).build
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
    end
  end
end
