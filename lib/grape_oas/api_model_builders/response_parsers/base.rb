# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Base module for response parser strategies
      # Each parser is responsible for extracting response specifications
      # from a specific format (e.g., :http_codes, documentation: { responses: ... })
      module Base
        # Parse response specifications from the route
        # @param route [Grape::Route] The route to parse
        # @return [Array<Hash>] Array of normalized response specs with keys:
        #   - code: HTTP status code
        #   - message: Response description
        #   - entity: Entity class for response schema
        #   - headers: Response headers
        #   - extensions: Custom x- extensions (optional)
        #   - examples: Response examples (optional)
        def parse(route)
          raise NotImplementedError, "#{self.class} must implement #parse"
        end

        # Check if this parser can handle the given route
        # @param route [Grape::Route] The route to check
        # @return [Boolean] true if this parser can parse the route
        def applicable?(route)
          raise NotImplementedError, "#{self.class} must implement #applicable?"
        end

        private

        # Extract status code from hash, supporting multiple key names
        def extract_status_code(hash, default_code)
          hash[:code] || hash[:status] || hash[:http_status] || default_code
        end

        # Extract description from hash, supporting multiple key names
        def extract_description(hash)
          hash[:message] || hash[:description] || hash[:desc]
        end

        # Extract entity from hash, supporting multiple key names
        def extract_entity(hash, fallback_entity)
          hash[:model] || hash[:entity] || fallback_entity
        end

        # Normalize hash keys (string -> symbol)
        def normalize_hash_keys(hash)
          return hash unless hash.is_a?(Hash)

          hash.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
        end

        # Default success status code for a route when none is explicitly provided.
        # POST routes default to 201; all other methods default to 200.
        # Honors an explicit `default_status:` route option.
        def default_success_code(route)
          return route.options[:default_status] if route.options[:default_status]

          route.request_method.to_s.upcase == "POST" ? 201 : 200
        end
      end
    end
  end
end
