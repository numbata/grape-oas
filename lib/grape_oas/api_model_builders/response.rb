# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Response
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

      # Response parsers in priority order
      # DocumentationResponsesParser has highest priority (most comprehensive)
      # HttpCodesParser handles legacy grape-swagger formats
      # DefaultResponseParser is the fallback
      def parsers
        @parsers ||= [
          ResponseParsers::DocumentationResponsesParser.new,
          ResponseParsers::HttpCodesParser.new,
          ResponseParsers::DefaultResponseParser.new
        ]
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
            "type" => header_spec[:type] || header_spec["type"] || "string",
            "description" => header_spec[:description] || header_spec[:desc]
          }.compact
        }
      end

      # Build schema for response body
      # Delegates to EntityIntrospector when entity is present
      def build_schema(entity_class)
        return GrapeOAS::ApiModel::Schema.new(type: "string") unless entity_class

        GrapeOAS::Introspectors::EntityIntrospector.new(entity_class).build_schema
      end

      def build_media_type(mime_type:, schema:)
        GrapeOAS::ApiModel::MediaType.new(
          mime_type: mime_type,
          schema: schema,
        )
      end

      def response_content_types
        default_format = route_default_format_from_route || default_format_from_app_or_api
        content_types = route_content_types_from_route
        content_types ||= content_types_from_app_or_api(default_format)

        mimes = []
        if content_types.is_a?(Hash)
          selected = content_types.select { |k, _| k.to_s.start_with?(default_format.to_s) } if default_format
          selected = content_types if selected.nil? || selected.empty?
          mimes = selected.values
        elsif content_types.respond_to?(:to_a) && !content_types.is_a?(String)
          mimes = content_types.to_a
        end

        mimes << mime_for_format(default_format) if mimes.empty? && default_format

        mimes = mimes.map { |m| normalize_mime(m) }.compact
        mimes.empty? ? ["application/json"] : mimes.uniq
      end

      def mime_for_format(format)
        return if format.nil?
        return format if format.to_s.include?("/")

        return unless defined?(Grape::ContentTypes::CONTENT_TYPES)

        Grape::ContentTypes::CONTENT_TYPES[format.to_sym]
      end

      def normalize_mime(mime_or_format)
        return nil if mime_or_format.nil?
        return mime_or_format if mime_or_format.to_s.include?("/")

        mime_for_format(mime_or_format)
      end

      def route_content_types_from_route
        return route.settings[:content_types] || route.settings[:content_type] if route.respond_to?(:settings)

        route.options[:content_types] || route.options[:content_type]
      end

      def route_default_format_from_route
        return route.settings[:default_format] if route.respond_to?(:settings)

        route.options[:format]
      end

      def default_format_from_app_or_api
        return api.default_format if api.respond_to?(:default_format)
        return app.default_format if app.respond_to?(:default_format)

        api.settings[:default_format] if api.respond_to?(:settings) && api.settings[:default_format]
      rescue StandardError
        nil
      end

      def content_types_from_app_or_api(default_format)
        source = if api.respond_to?(:content_types)
                   api.content_types
                 elsif app.respond_to?(:content_types)
                   app.content_types
                 elsif api.respond_to?(:settings)
                   api.settings[:content_types]
                 end

        return nil unless source.is_a?(Hash)

        return source unless default_format

        filtered = source.select { |k, _| k.to_s.start_with?(default_format.to_s) }
        filtered.empty? ? source : filtered
      rescue StandardError
        nil
      end
    end
  end
end
