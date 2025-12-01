# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Operation
      include Concerns::ContentTypeResolver

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
        @tag_names ||= Array(route.options[:tags]).presence || derive_tag_from_path
      end

      # Derive tag from path when no explicit tags are defined (like grape-swagger's tag_object)
      def derive_tag_from_path
        path = template_override || sanitize_route_path(route.path)
        # Remove path parameters like {id} and {version}
        path_without_params = path.gsub(/\{[^}]+\}/, "")
        segments = path_without_params.split("/").reject(&:empty?)

        # Remove prefix and version from segments
        prefix_segments = route_prefix_segments
        version_segments = route_version_segments

        filtered = segments.reject { |s| prefix_segments.include?(s) || version_segments.include?(s) }

        Array(filtered.first).presence || []
      end

      def route_prefix_segments
        prefix = route.prefix.to_s
        prefix.split("/").reject(&:empty?)
      end

      def route_version_segments
        version = route.version
        Array(version).map(&:to_s)
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
        resolve_content_types
      end

      def produces
        resolve_content_types
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
