# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Response
      include Concerns::ContentTypeResolver

      # Default response parsers in priority order
      # DocumentationResponsesParser has highest priority (most comprehensive)
      # HttpCodesParser handles legacy grape-swagger formats
      # DefaultResponseParser is the fallback
      DEFAULT_PARSERS = [
        ResponseParsers::DocumentationResponsesParser,
        ResponseParsers::HttpCodesParser,
        ResponseParsers::DefaultResponseParser
      ].freeze

      class << self
        attr_writer :parsers

        def parsers
          @parsers ||= DEFAULT_PARSERS.dup
        end

        def reset_parsers!
          @parsers = DEFAULT_PARSERS.dup
        end
      end

      attr_reader :api, :route, :app

      def initialize(api:, route:, app: nil)
        @api = api
        @route = route
        @app = app
      end

      def build
        response_specs.map { |spec| build_response_from_spec(spec) }
      end

      private

      # Use Strategy pattern to parse responses
      # Parsers are tried in order of priority
      def response_specs
        parser = parsers.find { |p| p.applicable?(route) }
        parser ? parser.parse(route) : []
      end

      def parsers
        @parsers ||= self.class.parsers.map(&:new)
      end

      def build_response_from_spec(spec)
        schema = build_schema(spec[:entity])
        media_types = Array(response_content_types).map do |mime|
          build_media_type(
            mime_type: mime,
            schema: schema,
          )
        end

        description = spec[:message].is_a?(String) ? spec[:message] : spec[:message].to_s

        GrapeOAS::ApiModel::Response.new(
          http_status: spec[:code].to_s,
          description: description || "Success",
          media_types: media_types,
          headers: normalize_headers(spec[:headers]) || headers_from_route,
          extensions: spec[:extensions] || extensions_from_route,
          examples: spec[:examples],
        )
      end

      def extensions_from_route
        ext = route.options[:documentation]&.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.nil? || ext.empty?
      end

      def normalize_headers(hdrs)
        return nil if hdrs.nil?
        return hdrs if hdrs.is_a?(Array)
        return nil unless hdrs.is_a?(Hash)

        hdrs.map { |name, h| build_header_schema(name, h) }
      end

      def headers_from_route
        hdrs = route.options.dig(:documentation, :headers) || route.settings.dig(:documentation, :headers)
        return [] unless hdrs.is_a?(Hash)

        hdrs.map { |name, h| build_header_schema(name, h) }
      end

      # Build a header schema, normalizing field names
      def build_header_schema(name, header_spec)
        {
          name: name,
          schema: {
            "type" => header_spec[:type] || header_spec["type"] || Constants::SchemaTypes::STRING,
            "description" => header_spec[:description] || header_spec[:desc]
          }.compact
        }
      end

      # Build schema for response body
      # Delegates to EntityIntrospector when entity is present
      def build_schema(entity_class)
        return GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::STRING) unless entity_class

        GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
      end

      def build_media_type(mime_type:, schema:)
        GrapeOAS::ApiModel::MediaType.new(
          mime_type: mime_type,
          schema: schema,
        )
      end

      def response_content_types
        resolve_content_types
      end
    end
  end
end
