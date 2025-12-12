# frozen_string_literal: true

require_relative "request_params_support/param_location_resolver"
require_relative "request_params_support/param_schema_builder"
require_relative "request_params_support/schema_enhancer"
require_relative "request_params_support/nested_params_builder"

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      ROUTE_PARAM_REGEX = /(?<=:)\w+/

      attr_reader :api, :route, :path_param_name_map

      def initialize(api:, route:, path_param_name_map: nil)
        @api = api
        @route = route
        @path_param_name_map = path_param_name_map || {}
      end

      def build
        route_params = route.path.scan(ROUTE_PARAM_REGEX)
        all_params = route.options[:params] || {}

        # Check if we have nested params (bracket notation)
        has_nested = all_params.keys.any? { |k| k.include?("[") }

        if has_nested
          build_with_nested_params(all_params, route_params)
        else
          build_flat_params(all_params, route_params)
        end
      end

      private

      # Builds params when nested structures are detected.
      def build_with_nested_params(all_params, route_params)
        body_schema = nested_params_builder.build(all_params, path_params: route_params)
        non_body_params = extract_non_body_params(all_params, route_params)

        [body_schema, non_body_params]
      end

      # Builds params for flat (non-nested) structures.
      def build_flat_params(all_params, route_params)
        body_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        path_params = []

        all_params.each do |name, spec|
          next if location_resolver.hidden_parameter?(spec)

          location = location_resolver.resolve(
            name: name,
            spec: spec,
            route_params: route_params,
            route: route,
          )
          required = spec[:required] || false
          schema = schema_builder.build(spec)
          mapped_name = path_param_name_map.fetch(name, name)

          if location == "body"
            body_schema.add_property(name, schema, required: required)
          else
            path_params << build_parameter(mapped_name, location, required, schema, spec)
          end
        end

        [body_schema, path_params]
      end

      # Extracts non-body params (path, query, header) from flat params.
      # For non-body HTTP methods (GET, HEAD, DELETE), also includes nested params
      # as flat query parameters with bracket notation (e.g., "tax_id[type]"),
      # unless request_body is explicitly enabled.
      def extract_non_body_params(all_params, route_params)
        params = []
        http_method = route.request_method.to_s.downcase
        flatten_nested = should_flatten_nested_to_query?(http_method, all_params)

        all_params.each do |name, spec|
          # Skip hidden params
          next if location_resolver.hidden_parameter?(spec)

          is_nested = name.include?("[")
          is_hash_param = location_resolver.body_param?(spec)

          # For nested bracket params (e.g., "tax_id[type]"), include as query params
          # for non-body HTTP methods (unless request_body is explicitly enabled)
          if is_nested
            next unless flatten_nested

            params << build_parameter(name, "query", spec[:required] || false, schema_builder.build(spec), spec)
            next
          end

          # Skip Hash type params (they're handled via nested bracket params above
          # or via body schema for POST/PUT/PATCH)
          next if is_hash_param

          location = location_resolver.resolve(
            name: name,
            spec: spec,
            route_params: route_params,
            route: route,
          )
          next if location == "body"

          mapped_name = path_param_name_map.fetch(name, name)
          params << build_parameter(mapped_name, location, spec[:required] || false, schema_builder.build(spec), spec)
        end

        params
      end

      # Determines whether nested params should be flattened to query params.
      # Returns true for GET/HEAD/DELETE unless body is explicitly requested via:
      # - route-level `request_body: true` option
      # - any parameter with `documentation: { in: 'body' }` or `documentation: { param_type: 'body' }`
      def should_flatten_nested_to_query?(http_method, all_params)
        return false unless Constants::HttpMethods::BODYLESS_HTTP_METHODS.include?(http_method)

        # If request_body is explicitly enabled at route level, use body schema
        return false if route.options.dig(:documentation, :request_body) || route.options[:request_body]

        # If any parameter is explicitly marked as body, use body schema
        has_explicit_body_param = all_params.any? do |name, spec|
          next false if name.include?("[") # Skip bracket params, check parent Hash params only

          param_type = spec.dig(:documentation, :param_type)&.to_s&.downcase
          in_location = spec.dig(:documentation, :in)&.to_s&.downcase
          param_type == "body" || in_location == "body"
        end

        !has_explicit_body_param
      end

      def build_parameter(name, location, required, schema, spec)
        ApiModel::Parameter.new(
          location: location,
          name: name,
          required: required,
          schema: schema,
          description: spec[:documentation]&.dig(:desc),
          collection_format: extract_collection_format(spec),
        )
      end

      def extract_collection_format(spec)
        spec.dig(:documentation, :collectionFormat) || spec.dig(:documentation, :collection_format)
      end

      def location_resolver
        RequestParamsSupport::ParamLocationResolver
      end

      def schema_builder
        @schema_builder ||= RequestParamsSupport::ParamSchemaBuilder.new
      end

      def nested_params_builder
        @nested_params_builder ||= RequestParamsSupport::NestedParamsBuilder.new(schema_builder: schema_builder)
      end
    end
  end
end
