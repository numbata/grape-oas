# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Operation
      attr_reader :api, :route, :app, :path_param_name_map, :template_override

      def initialize(api:, route:, app: nil, path_param_name_map: nil, template_override: nil)
        @api = api
        @route = route
        @app = app
        @path_param_name_map = path_param_name_map || {}
        @template_override = template_override
      end

      def build
        operation = GrapeOAS::ApiModel::Operation.new(
          http_method: http_method,
          operation_id: operation_id,
          summary: route.options[:description],
          tag_names: tag_names,
          extensions: operation_extensions,
          consumes: consumes,
          produces: produces,
        )

        api.add_tags(*tag_names) if tag_names.any?

        build_request(operation)

        build_responses.each { |resp| operation.add_response(resp) }
        ensure_path_parameters(operation)

        operation.security = build_security if build_security

        operation
      end

      private

      def operation_id
        @operation_id ||= route.options.fetch(:nickname) do
          slug = route
                 .pattern
                 .origin
                 .gsub(/[^a-z0-9]+/i, "_")
                 .gsub(/_+/, "_")
                 .sub(/^_|_$/, "")

          "#{http_method}_#{slug}"
        end
      end

      def http_method
        @http_method ||= route.request_method.downcase.to_sym
      end

      def tag_names
        @tag_names ||= Array(route.options[:tags])
      end

      def build_response
        GrapeOAS::ApiModelBuilders::Response
          .new(api: api, route: route, app: app)
          .build
      end

      def build_responses
        Array(build_response)
      end

      def build_security
        route.options.dig(:documentation, :security) ||
          route.options[:security] ||
          route.options[:auth]
      end

      def consumes
        route_content_types
      end

      def produces
        route_content_types
      end

      def route_content_types
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

      def operation_extensions
        doc = route.options[:documentation]
        return nil unless doc.is_a?(Hash)

        ext = doc.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.empty?
      end

      def build_request(operation)
        GrapeOAS::ApiModelBuilders::Request
          .new(api: api, route: route, operation: operation, path_param_name_map: path_param_name_map)
          .build
      end

      # Ensure every {param} in the path template has a corresponding path parameter.
      def ensure_path_parameters(operation)
        template = template_override || sanitize_route_path(route.path)
        placeholders = template.scan(/\{([^}]+)\}/).flatten
        existing = Array(operation.parameters).select { |p| p.location == "path" }.map(&:name)
        missing = placeholders - existing
        missing.each do |name|
          operation.add_parameter(
            GrapeOAS::ApiModel::Parameter.new(
              location: "path",
              name: name,
              required: true,
              schema: GrapeOAS::ApiModel::Schema.new(type: "string"),
            ),
          )
        end
      end

      def sanitize_route_path(path)
        path.gsub(Path::EXTENSION_PATTERN, "").gsub(Path::PATH_PARAMETER_PATTERN, "{\\k<param>}")
      end
    end
  end
end
