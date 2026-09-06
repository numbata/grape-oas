# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      include Concerns::RouteValidations

      ROUTE_PARAM_REGEX = /(?<=[:*])\w+/

      def self.path_param_names(path)
        path.sub(/(\(\.[^)]+\))+$/, "").scan(ROUTE_PARAM_REGEX)
      end

      attr_reader :api, :route, :path_param_name_map

      def initialize(api:, route:, path_param_name_map: nil)
        @api = api
        @route = route
        @path_param_name_map = path_param_name_map || {}
      end

      def build
        route_params = self.class.path_param_names(route.path)
        all_params = declared_params

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
        doc = spec[:documentation] || {}
        style = doc.fetch(:style) { doc["style"] }
        explode = doc.fetch(:explode) { doc["explode"] }

        ApiModel::Parameter.new(
          location: location,
          name: name,
          required: required,
          schema: schema,
          description: spec[:documentation]&.dig(:desc) || spec[:desc],
          collection_format: extract_collection_format(spec),
          style: style,
          explode: explode,
        )
      end

      def extract_collection_format(spec)
        spec.dig(:documentation, :collectionFormat) || spec.dig(:documentation, :collection_format)
      end

      # Grape 3.x stores documented params in `route.options[:params]`.
      # Grape 4.0 moved them to `Route#params` (grape#2785) and no longer
      # copies the hash into options. Path captures that are not Hash specs
      # (empty-string defaults from the pattern) are dropped.
      def declared_params
        specs = params_from_options || params_from_route
        return {} unless specs.is_a?(Hash)

        flat = specs.select { |_name, spec| spec.is_a?(Hash) }
        conditional = conditional_param_names
        return flat if conditional.empty?

        flat.each_with_object({}) do |(name, spec), params|
          params[name] = conditional.include?(name.to_s) ? spec.merge(required: false) : spec
        end
      end

      # Returns names of params that Grape will only validate conditionally
      # (declared inside a `given` block). Their validators have a
      # `params_scope` with `@dependent_on` set.
      def conditional_param_names
        return Set.new unless route.respond_to?(:app) && route.app.respond_to?(:inheritable_setting)

        validations = grape_route_validations(route.app.inheritable_setting)
        return Set.new unless validations.is_a?(Array)

        conditional = Set.new
        unconditional = Set.new
        validations.each do |validator|
          scope, attrs = validator_details(validator)
          next unless scope.respond_to?(:full_name)

          target = conditional_scope?(scope) ? conditional : unconditional
          Array(attrs).each { |attr| target << scope.full_name(attr) }
        end
        conditional - unconditional
      end

      # Grape < 3.2 stores validators as hashes; >= 3.2 stores instances.
      def validator_details(validator)
        presence = Grape::Validations::Validators::PresenceValidator
        if validator.is_a?(Hash)
          return unless validator[:validator_class].is_a?(Class) && validator[:validator_class] <= presence

          [validator[:params_scope], validator[:attributes]]
        elsif validator.is_a?(presence)
          [validator.instance_variable_get(:@scope), validator.attrs]
        end
      end

      def conditional_scope?(scope)
        while scope
          return true if scope.instance_variable_get(:@dependent_on)&.any?

          scope = scope.respond_to?(:parent) ? scope.parent : nil
        end
        false
      end

      def params_from_options
        params = route.options[:params]
        params if params.is_a?(Hash) && params.any?
      end

      def params_from_route
        return unless route.respond_to?(:params)
        # Grape 3.x Route#params(input = nil) merges path captures; skip it.
        # Grape 4.0 Route#params takes no arguments and is the documentation hash.
        return unless route.method(:params).arity.zero?

        params = route.params
        params if params.is_a?(Hash) && params.any?
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
