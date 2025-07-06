# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Path
      EXTENSION_PATTERN = /\(\.json\)$/
      private_constant :EXTENSION_PATTERN

      PATH_PARAMETER_PATTERN = %r{(?<=/):(?<param>[^/]+)}
      private_constant :PATH_PARAMETER_PATTERN

      attr_reader :api, :routes

      def initialize(api:, routes:)
        @api = api
        @routes = routes
      end

      def build
        @routes.each_with_object({}) do |route, api_routes|
          next if skip_route?(route)

          route_path = sanitize_path(route.path)
          api_path = api_routes.fetch(route_path) do
            path = GrapeOAS::ApiModel::Path.new(template: route_path)
            api_routes[route_path] = path

            api.add_path(path)

            path
          end

          operation = build_operation(route)

          api_path.add_operation(operation)
        end
      end

      private

      def skip_route?(route)
        route.settings.dig(:swagger, :hidden)
      end

      def build_operation(route)
        GrapeOAS::ApiModelBuilders::Operation
          .new(api: api, route: route)
          .build
      end

      def sanitize_path(path)
        path
          .gsub(EXTENSION_PATTERN, "") # Remove format extensions like (.json)
          .gsub(PATH_PARAMETER_PATTERN, "{\\k<param>}") # Replace named parameters with curly braces
      end
    end
  end
end
