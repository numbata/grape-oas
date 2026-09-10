# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module RequestParamsSupport
      # Resolves the location (path, query, body, header) for a parameter.
      class ParamLocationResolver
        # Locations `param_type:`/`in:` may explicitly name. An unrecognized
        # value (a typo, or a grape-swagger location this library doesn't
        # resolve to, like `formData`) is treated as unset rather than
        # emitted verbatim, since nothing downstream validates `Parameter#location`.
        VALID_EXPLICIT_LOCATIONS = %w[body query header path cookie].freeze

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

        # Checks if a parameter is a Hash type. Hash parents are represented
        # by their children (nested params) or the request body, never
        # themselves as a parameter.
        #
        # @param spec [Hash] the parameter specification
        # @return [Boolean] true if the parameter type is Hash
        def self.hash_param?(spec)
          [Hash, "Hash"].include?(spec[:type])
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

        def self.route_body_opted_in?(route)
          !!(route.options[:body_name] || route.options.dig(:documentation, :request_body) || route.options[:request_body])
        end

        class << self
          private

          # Extracts the parameter location from the specification.
          # Supports both `param_type` and `in` options for grape-swagger compatibility.
          #
          # Precedence (highest to lowest):
          #   1. `param_type` option (e.g., `documentation: { param_type: 'query' }`)
          #   2. `in` option (e.g., `documentation: { in: 'query' }`)
          #   3. Defaults to "body" for write methods (POST/PUT/PATCH), "query" for read methods
          #
          # Note: If both `param_type` and `in` are specified, `param_type` takes precedence.
          # For example, `{ param_type: 'query', in: 'body' }` will be treated as query.
          #
          # `resolve` already returns "path" for an actual route capture before
          # calling this method, so an explicit `in: "path"` / `param_type: "path"`
          # reaching here is always a mismatch (the name can never appear in the
          # URL template) and is ignored, same as an unrecognized location.
          #
          # @param spec [Hash] the parameter specification
          # @param route [Object] the Grape route object
          # @return [String] the parameter location
          def extract_from_spec(spec, route)
            location = explicit_location(spec)
            location = nil if location == "path"
            return "body" if route_body_opted_in?(route) && location.nil?

            # Support both param_type and in for grape-swagger compatibility
            # param_type takes precedence over in when both are specified
            return location if location

            # Default: body for write methods (POST/PUT/PATCH), query for read methods (GET/DELETE/HEAD)
            http_method = route.request_method.to_s.downcase
            Constants::HttpMethods::BODYLESS_HTTP_METHODS.include?(http_method) ? "query" : "body"
          end

          def explicit_location(spec)
            doc = spec[:documentation] || {}
            param_type = doc[:param_type] || doc["param_type"]
            in_location = doc[:in] || doc["in"]
            location = (param_type || in_location)&.to_s&.downcase
            location if VALID_EXPLICIT_LOCATIONS.include?(location)
          end
        end
      end
    end
  end
end
