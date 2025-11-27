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

      attr_reader :api, :routes, :app

      def initialize(api:, routes:, app: nil)
        @api = api
        @routes = routes
        @app = app
      end

      def build
        canonical_paths = {}

        @routes.each_with_object({}) do |route, api_routes|
          next if skip_route?(route)

          route_path = sanitize_path(route.path)
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
        # Check both options and settings for backward compatibility
        route.options.dig(:swagger, :hidden) || route.settings.dig(:swagger, :hidden)
      end

      def build_operation(route, path_param_name_map: nil, template_override: nil)
        GrapeOAS::ApiModelBuilders::Operation
          .new(api: api, route: route, app: app, path_param_name_map: path_param_name_map, template_override: template_override)
          .build
      end

      def sanitize_path(path)
        path
          .gsub(EXTENSION_PATTERN, "") # Remove format extensions like (.json)
          .gsub(PATH_PARAMETER_PATTERN, "{\\k<param>}") # Replace named parameters with curly braces
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
