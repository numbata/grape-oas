# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Resolves the location (path, query, body, header) for a parameter.
      class ParamLocationResolver
        # Determines the location for a parameter.
        #
        # @param name [String] the parameter name
        # @param spec [Hash] the parameter specification
        # @param route_params [Array<String>] list of path parameter names
        # @param route [Object] the Grape route object
        # @return [String] the parameter location ("path", "query", "body", "header")
        def self.resolve(name:, spec:, route_params:, route:)
          return "path" if route_params.include?(name)

          extract_from_spec(spec, route)
        end

        # Checks if a parameter should be in the request body.
        #
        # @param spec [Hash] the parameter specification
        # @return [Boolean] true if it's a body parameter
        def self.body_param?(spec)
          spec.dig(:documentation, :param_type) == "body" || [Hash, "Hash"].include?(spec[:type])
        end

        # Checks if a parameter is explicitly marked as NOT a body param.
        #
        # @param spec [Hash] the parameter specification
        # @return [Boolean] true if explicitly non-body
        def self.explicit_non_body_param?(spec)
          param_type = spec.dig(:documentation, :param_type)&.to_s&.downcase
          param_type && %w[query header path].include?(param_type)
        end

        # Checks if a parameter should be hidden from documentation.
        # Required parameters are never hidden (matching grape-swagger behavior).
        #
        # @param spec [Hash] the parameter specification
        # @return [Boolean] true if hidden
        def self.hidden_parameter?(spec)
          return false if spec[:required]

          hidden = spec.dig(:documentation, :hidden)
          hidden = hidden.call if hidden.respond_to?(:call)
          hidden
        end

        class << self
          private

          def extract_from_spec(spec, route)
            # If body_name is set on the route, treat non-path params as body by default
            return "body" if route.options[:body_name] && !spec.dig(:documentation, :param_type)

            spec.dig(:documentation, :param_type)&.downcase || "query"
          end
        end
      end
    end
  end
end
