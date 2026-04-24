# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Path
      # Matches format extensions like (.json), (.:format), (.json)(.:format)
      EXTENSION_PATTERN = /(\(\.[^)]+\))+$/
      private_constant :EXTENSION_PATTERN

      PATH_PARAMETER_PATTERN = %r{(?<=/):(?<param>[^/]+)}
      private_constant :PATH_PARAMETER_PATTERN

      NORMALIZED_PLACEHOLDER = /\{[^}]+\}/
      private_constant :NORMALIZED_PLACEHOLDER

      attr_reader :api, :routes, :app, :namespace_filter

      def initialize(api:, routes:, app: nil, namespace_filter: nil)
        @api = api
        @routes = routes
        @app = app
        @namespace_filter = namespace_filter
      end

      def build
        canonical_paths = {}

        @routes.each_with_object({}) do |route, api_routes|
          next if skip_route?(route)

          route_path = sanitize_path(route.path, version: route.version)
          normalized = normalize_template(route_path)

          canonical_info = canonical_paths[normalized]
          path_param_name_map = nil

          if canonical_info
            path_param_name_map = map_param_names(canonical_info[:template], route_path)
            route_path = canonical_info[:template]
          else
            canonical_paths[normalized] = { template: route_path }
          end

          api_path = api_routes.fetch(route_path) do
            path = GrapeOAS::ApiModel::Path.new(template: route_path)
            api_routes[route_path] = path

            api.add_path(path)

            path
          end

          operation = build_operation(route, path_param_name_map: path_param_name_map, template_override: route_path)

          api_path.add_operation(operation)
        end
      end

      private

      def skip_route?(route)
        return true if filtered_by_namespace?(route)

        # Check route_setting :swagger, hidden: true
        route_hidden = route.settings.dig(:swagger, :hidden)
        # Check desc "...", swagger: { hidden: true }
        route_hidden = route.options.dig(:swagger, :hidden) if route.options.dig(:swagger, :hidden)
        # Direct hidden option takes precedence (from desc hidden: or verb method options)
        route_hidden = route.options[:hidden] if route.options.key?(:hidden)

        # Support callable objects (Proc/lambda) for conditional hiding
        route_hidden = route_hidden.call if route_hidden.respond_to?(:call)

        route_hidden
      end

      # Returns true if route should be filtered out due to namespace filter.
      # Routes are included if their path matches the namespace exactly or starts with namespace followed by "/".
      def filtered_by_namespace?(route)
        return false unless namespace_filter

        route_path = sanitize_path(route.path, version: route.version)
        namespace_prefix = namespace_filter.start_with?("/") ? namespace_filter : "/#{namespace_filter}"

        # Match exact namespace or namespace followed by / or {
        return false if route_path == namespace_prefix
        return false if route_path.start_with?("#{namespace_prefix}/")

        true
      end

      def build_operation(route, path_param_name_map: nil, template_override: nil)
        GrapeOAS::ApiModelBuilders::Operation
          .new(api: api, route: route, app: app, path_param_name_map: path_param_name_map, template_override: template_override)
          .build
      end

      def sanitize_path(path, version: nil)
        sanitized = path.gsub(EXTENSION_PATTERN, "") # Remove format extensions like (.json)
                        .gsub(PATH_PARAMETER_PATTERN, "{\\k<param>}") # Replace named parameters with curly braces

        concrete_version = concrete_path_version(version)
        sanitized = sanitized.sub("{version}", concrete_version) if concrete_version && path_version_segment?(path)

        sanitized
      end

      def path_version_segment?(path)
        path.start_with?("/:version/", "/:version(") || path == "/:version"
      end

      def concrete_path_version(version)
        values = Array(version)
        return nil unless values.length == 1

        values.first.to_s
      end

      def normalize_template(path)
        sanitize_path(path).gsub(NORMALIZED_PLACEHOLDER, "{}")
      end

      def map_param_names(canonical_template, incoming_template)
        canonical_params = canonical_template.scan(/\{([^}]+)\}/).flatten
        incoming_params = incoming_template.scan(/\{([^}]+)\}/).flatten
        return nil unless canonical_params.length == incoming_params.length

        mapping = incoming_params.zip(canonical_params).to_h
        # Only return mapping when names differ to avoid needless work
        mapping if mapping.any? && mapping.keys != mapping.values
      end

      public_constant :EXTENSION_PATTERN
      public_constant :PATH_PARAMETER_PATTERN
    end
  end
end
