# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Request
      include Concerns::TypeResolver
      include Concerns::OasUtilities

      attr_reader :api, :route, :operation, :path_param_name_map

      def initialize(api:, route:, operation:, path_param_name_map: nil)
        @api = api
        @route = route
        @operation = operation
        @path_param_name_map = path_param_name_map || {}
      end

      def build
        body_schema, route_params = GrapeOAS::ApiModelBuilders::RequestParams
                                    .new(api: api, route: route, path_param_name_map: path_param_name_map)
                                    .build

        contract_schema = build_contract_schema

        # For GET/HEAD/DELETE requests, convert contract schema to query parameters
        # instead of putting it in request body, UNLESS request_body is explicitly enabled
        if contract_schema && should_convert_contract_to_query_params?
          contract_params = convert_contract_schema_to_params(contract_schema)
          operation.add_parameters(*contract_params)
        elsif contract_schema
          body_schema = contract_schema
        end

        operation.add_parameters(*route_params)
        append_request_body(body_schema) unless body_schema.empty?
      end

      private

      def append_request_body(body_schema)
        # OAS spec says GET/HEAD/DELETE "MAY ignore" request bodies
        # Skip by default unless explicitly allowed via documentation option
        http_method = operation.http_method.to_s.downcase
        if Constants::HttpMethods::BODYLESS_HTTP_METHODS.include?(http_method)
          allow_body = route.options.dig(:documentation, :request_body) ||
                       route.options[:request_body]
          return unless allow_body
        end

        media_ext = media_type_extensions(Constants::MimeTypes::JSON)

        # Set canonical_name if not already set (e.g., DryIntrospector may have set it for polymorphism)
        if body_schema.respond_to?(:canonical_name) && body_schema.canonical_name.nil?
          contract = find_contract

          if contract
            # Dry contracts are kept inline (no canonical_name)
            # no-op
          elsif body_schema.properties.values.any? { |prop| prop.respond_to?(:canonical_name) && prop.canonical_name }
            # keep entity/property refs intact; don't override
          elsif operation.respond_to?(:operation_id) && operation.operation_id
            body_schema.canonical_name = "#{operation.operation_id}_Request"
          end
        end

        media_types = Array(operation.consumes.presence || [Constants::MimeTypes::JSON]).map do |mime|
          GrapeOAS::ApiModel::MediaType.new(
            mime_type: mime,
            schema: body_schema,
            extensions: media_ext,
          )
        end
        operation.request_body = GrapeOAS::ApiModel::RequestBody.new(
          required: body_schema.required && !body_schema.required.empty?,
          media_types: media_types,
          extensions: request_body_extensions,
          body_name: route.options[:body_name],
        )
      end

      def documentation_options
        route.options[:documentation] || {}
      end

      def request_body_extensions
        extract_extensions(documentation_options)
      end

      def media_type_extensions(mime)
        content = documentation_options[:content]
        return nil unless content.is_a?(Hash)

        mt = content[mime] || content[mime.to_sym]
        extract_extensions(mt)
      end

      # Find contract from Grape's contract storage locations.
      # Contracts can be defined in several ways:
      # 1. Via `contract MyContract` DSL - stores in inheritable_setting.route[:saved_validations]
      # 2. Via `desc "...", contract: MyContract` - stores in route.options[:contract]
      # 3. Via `desc "...", schema: MySchema` - stores in route.options[:schema]
      # 4. Via route.settings[:contract] - used by mounted APIs or legacy configuration
      #
      # @return [Object, nil] The contract instance or nil if not found
      def find_contract
        # Check route options first (from desc "...", contract: MyContract or schema: MySchema)
        contract = route.options[:contract] || route.options[:schema]
        return contract if contract

        # Check route settings (mounted APIs or legacy configuration)
        contract = route.settings[:contract] if route.respond_to?(:settings)
        return contract if contract

        # Check Grape's native contract() DSL storage
        extract_contract_from_grape_validations
      end

      # Extract contract from Grape's native contract() DSL storage location.
      # When using `contract MyContract` in Grape DSL, the contract is stored in
      # route.app.inheritable_setting.route[:saved_validations] as validator options.
      # This is a point-in-time copy specific to this endpoint, ensuring each route
      # gets only its own contract even when multiple routes define different contracts.
      #
      # @return [Object, nil] The contract instance or nil if not found
      def extract_contract_from_grape_validations
        return unless route.respond_to?(:app) && route.app.respond_to?(:inheritable_setting)

        setting = route.app.inheritable_setting
        return unless setting.respond_to?(:route)

        # Use route[:saved_validations] which contains only the validations
        # for this specific endpoint (point-in-time copy), not the shared
        # namespace_stackable[:validations] which contains all validators for the API class
        validations = setting.route[:saved_validations]
        return unless validations.is_a?(Array)

        # Find ContractScopeValidator which holds the Dry contract/schema
        contract_validation = validations.find do |v|
          next unless v.is_a?(Hash)

          validator_class = v[:validator_class]
          validator_class.is_a?(Class) &&
            defined?(Grape::Validations::Validators::ContractScopeValidator) &&
            validator_class <= Grape::Validations::Validators::ContractScopeValidator
        end

        return unless contract_validation

        # The contract instance is stored in opts[:schema]
        contract_validation.dig(:opts, :schema)
      end

      def build_contract_schema
        contract = find_contract
        return unless contract

        schema_obj = if contract.respond_to?(:schema)
                       contract.schema
                     elsif contract.respond_to?(:call)
                       contract
                     end

        # Pass the contract class (not schema_obj) so DryIntrospector can detect inheritance
        return GrapeOAS::Introspectors::DryIntrospector.build(contract) if schema_obj.respond_to?(:types)

        contract_hash = if contract.respond_to?(:to_h)
                          contract.to_h
                        elsif contract.respond_to?(:schema) && contract.schema.respond_to?(:to_h)
                          contract.schema.to_h
                        end
        return unless contract_hash.is_a?(Hash)

        hash_to_schema(contract_hash)
      end

      def hash_to_schema(obj)
        schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        obj.each do |key, value|
          case value
          when Hash
            schema.add_property(key, hash_to_schema(value))
          when Array
            item_schema = if value.first.is_a?(Hash)
                            hash_to_schema(value.first)
                          else
                            GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
                          end
            schema.add_property(key, GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: item_schema))
          else
            prop_schema = GrapeOAS::ApiModel::Schema.new(type: map_type(value))
            prop_schema.nullable = true if value.nil?
            schema.add_property(key, prop_schema)
          end
        end
        schema
      end

      def map_type(value)
        return value.primitive.to_s.downcase if value.respond_to?(:primitive)

        # First try direct lookup (for Ruby class values like String, Integer)
        # Then try class-based lookup (for actual runtime values like "hello", 123)
        Constants::RUBY_TYPE_MAPPING[value] ||
          Constants::RUBY_TYPE_MAPPING[value.class] ||
          Constants::SchemaTypes::STRING
      end

      def convert_contract_schema_to_params(schema)
        return [] unless schema.respond_to?(:properties)

        params = []
        param_docs = contract_param_documentation
        path_params = path_param_names

        schema.properties.each do |name, prop_schema|
          name_s = name.to_s
          next if path_params.include?(name_s)

          required = schema.required&.any? { |r| r.to_s == name_s } || false
          doc = param_docs[name_s] || {}
          params << build_query_parameter(name_s, prop_schema, required, doc)
        end

        params
      end

      def should_convert_contract_to_query_params?
        http_method = operation.http_method.to_s.downcase
        return false unless Constants::HttpMethods::BODYLESS_HTTP_METHODS.include?(http_method)

        !(route.options.dig(:documentation, :request_body) || route.options[:request_body])
      end

      def build_query_parameter(name, schema, required, doc = {})
        style = doc.fetch(:style) { doc["style"] }
        explode = doc.fetch(:explode) { doc["explode"] }
        description = doc[:desc] || doc[:description] || schema.description
        ApiModel::Parameter.new(
          location: "query",
          name: name,
          required: required,
          schema: schema,
          description: description,
          style: style,
          explode: explode,
        )
      end

      def contract_param_documentation
        params = documentation_options[:params]
        return {} unless params.is_a?(Hash)

        params.each_with_object({}) do |(key, value), acc|
          acc[key.to_s] = value.is_a?(Hash) ? value : {}
        end
      end

      def path_param_names
        names = route.path.scan(RequestParams::ROUTE_PARAM_REGEX)
        mapped_names = path_param_name_map ? path_param_name_map.values : []
        (names + mapped_names).map(&:to_s).uniq
      end
    end
  end
end
