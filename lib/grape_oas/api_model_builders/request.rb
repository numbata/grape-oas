# frozen_string_literal: true

require "bigdecimal"

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
          settings = route.respond_to?(:settings) ? route.settings : {}
          contract_class = route.options[:contract] || route.options[:schema] || settings[:contract]

          if contract_class.is_a?(Class) && defined?(Menti::Endpoint::Schema) && contract_class < Menti::Endpoint::Schema
            body_schema.canonical_name = contract_class.name
          elsif contract_class # some other contract (e.g., Dry); keep inline
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

      def build_contract_schema
        settings = route.respond_to?(:settings) ? route.settings : {}
        contract = route.options[:contract] || settings[:contract]
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
        Constants::RUBY_TYPE_MAPPING.fetch(value) do
          Constants::RUBY_TYPE_MAPPING.fetch(value.class, Constants::SchemaTypes::STRING)
        end
      end

      def schema_from_types(types_hash, rule_constraints)
        schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
        types_hash.each do |name, dry_type|
          prop_schema = schema_for_type(dry_type)
          merge_rule_constraints(prop_schema, rule_constraints[name]) if rule_constraints[name]
          required = true
          required = false if dry_type.respond_to?(:optional?) && dry_type.optional?
          required = false if dry_type.respond_to?(:meta) && dry_type.meta[:omittable]
          schema.add_property(name, prop_schema, required: required)
        end
        schema
      end

      def schema_for_type(dry_type)
        if dry_type.respond_to?(:primitive) && dry_type.primitive == Array && dry_type.respond_to?(:member)
          items_schema = schema_for_type(dry_type.member)
          schema = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
          apply_array_meta_constraints(schema, dry_type.respond_to?(:meta) ? dry_type.meta : {})
          return schema
        end

        primitive, member = derive_primitive_and_member(dry_type)
        if dry_type.respond_to?(:primitive) && dry_type.primitive == Array
          member ||= dry_type.respond_to?(:member) ? dry_type.member : nil
          primitive = Array
        end
        meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
        nullable = dry_type.respond_to?(:optional?) && dry_type.optional?
        enum_vals = dry_type.respond_to?(:values) ? dry_type.values : nil

        schema = if primitive == Array
                   items_schema = member ? schema_for_type(member) : default_string_schema
                   s = GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
                   apply_array_meta_constraints(s, meta)
                   s
                 else
                   build_schema_for_primitive(primitive)
                 end

        schema.nullable = nullable
        schema.enum = enum_vals if enum_vals
        apply_string_meta_constraints(schema, meta) if primitive == String
        apply_numeric_meta_constraints(schema, meta) if [Integer, Float, BigDecimal].include?(primitive)
        schema
      end

      def derive_primitive_and_member(dry_type)
        if defined?(Dry::Types::Array::Member) && dry_type.respond_to?(:type) && dry_type.type.is_a?(Dry::Types::Array::Member)
          return [Array, dry_type.type.member]
        end

        return [Array, dry_type.member] if dry_type.respond_to?(:member)

        primitive = dry_type.respond_to?(:primitive) ? dry_type.primitive : nil
        [primitive, nil]
      end

      def apply_string_meta_constraints(schema, meta)
        min_length = extract_min_constraint(meta)
        max_length = extract_max_constraint(meta)
        schema.min_length = min_length if min_length
        schema.max_length = max_length if max_length
        schema.pattern = meta[:pattern] if meta[:pattern]
      end

      def apply_array_meta_constraints(schema, meta)
        min_items = extract_min_constraint(meta, :min_items)
        max_items = extract_max_constraint(meta, :max_items)
        schema.min_items = min_items if min_items
        schema.max_items = max_items if max_items
      end

      # Extract minimum constraint, supporting multiple key names
      def extract_min_constraint(meta, specific_key = :min_length)
        meta[:min_size] || meta[specific_key]
      end

      # Extract maximum constraint, supporting multiple key names
      def extract_max_constraint(meta, specific_key = :max_length)
        meta[:max_size] || meta[specific_key]
      end

      def apply_numeric_meta_constraints(schema, meta)
        if meta[:gt]
          schema.minimum = meta[:gt]
          schema.exclusive_minimum = true
        elsif meta[:gteq]
          schema.minimum = meta[:gteq]
        end
        if meta[:lt]
          schema.maximum = meta[:lt]
          schema.exclusive_maximum = true
        elsif meta[:lteq]
          schema.maximum = meta[:lteq]
        end
      end

      def merge_rule_constraints(schema, rule_constraints)
        return unless rule_constraints

        schema.enum ||= rule_constraints[:enum]
        schema.nullable ||= rule_constraints[:nullable]
        schema.min_length ||= rule_constraints[:min] if rule_constraints[:min]
        schema.max_length ||= rule_constraints[:max] if rule_constraints[:max]
        schema.minimum ||= rule_constraints[:minimum] if rule_constraints[:minimum]
        schema.maximum ||= rule_constraints[:maximum] if rule_constraints[:maximum]
        schema.exclusive_minimum ||= rule_constraints[:exclusive_minimum]
        schema.exclusive_maximum ||= rule_constraints[:exclusive_maximum]
      end

      # Very small parser for FakeType rule_ast used in tests
      def extract_rule_constraints(schema_obj)
        return {} unless schema_obj.respond_to?(:rules)

        # Only supports FakeSchema/FakeType used in tests
        constraints = Hash.new { |h, k| h[k] = {} }
        if schema_obj.respond_to?(:types)
          schema_obj.types.each do |name, dry_type|
            next unless dry_type.respond_to?(:rule_ast)

            rules = dry_type.rule_ast
            Array(rules).each do |rule|
              next unless rule.is_a?(Array)

              _, pred = rule
              next unless pred.is_a?(Array)

              pname, pargs = pred
              case pname
              when :size?
                min, max = Array(pargs).first
                constraints[name][:min] = min
                constraints[name][:max] = max
              when :maybe
                constraints[name][:nullable] = true
              end
            end
          end
        end
        constraints
      rescue NoMethodError, TypeError
        {}
      end

      def extract_enum_from_core_values(core)
        return unless core.respond_to?(:values)

        vals = core.values
        vals if vals.is_a?(Array)
      rescue NoMethodError
        nil
      end

      def convert_contract_schema_to_params(schema)
        return [] unless schema.respond_to?(:properties)

        params = []
        param_docs = contract_param_documentation
        path_params = path_param_names

        schema.properties.each do |name, prop_schema|
          name_s = name.to_s
          next if path_params.include?(name_s)

          required = schema.required&.include?(name_s) || false
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
        ApiModel::Parameter.new(
          location: "query",
          name: name,
          required: required,
          schema: schema,
          description: schema.description,
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
