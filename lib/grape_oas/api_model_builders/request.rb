# frozen_string_literal: true

require "bigdecimal"

module GrapeOAS
  module ApiModelBuilders
    class Request
      attr_reader :api, :route, :operation

      def initialize(api:, route:, operation:)
        @api = api
        @route = route
        @operation = operation
      end

      def build
        body_schema, route_params = GrapeOAS::ApiModelBuilders::RequestParams
                                    .new(api: api, route: route)
                                    .build

        contract_schema = build_contract_schema
        body_schema = contract_schema if contract_schema

        operation.add_parameters(*route_params)
        append_request_body(body_schema) unless body_schema.empty?
      end

      private

      def append_request_body(body_schema)
        media_ext = media_type_extensions("application/json")
        media_type = GrapeOAS::ApiModel::MediaType.new(
          mime_type: "application/json",
          schema: body_schema,
          extensions: media_ext,
        )
        operation.request_body = GrapeOAS::ApiModel::RequestBody.new(
          required: body_schema.required && !body_schema.required.empty?,
          media_types: [media_type],
          extensions: request_body_extensions,
        )
      end

      def documentation_options
        route.options[:documentation] || {}
      end

      def request_body_extensions
        ext = documentation_options.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.empty?
      end

      def media_type_extensions(mime)
        content = documentation_options[:content]
        return nil unless content.is_a?(Hash)

        mt = content[mime] || content[mime.to_sym]
        return nil unless mt.is_a?(Hash)

        ext = mt.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.empty?
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

        return GrapeOAS::Introspectors::DryIntrospector.build(schema_obj) if schema_obj.respond_to?(:types)

        contract_hash = if contract.respond_to?(:to_h)
                          contract.to_h
                        elsif contract.respond_to?(:schema) && contract.schema.respond_to?(:to_h)
                          contract.schema.to_h
                        end
        return unless contract_hash.is_a?(Hash)

        hash_to_schema(contract_hash)
      end

      def hash_to_schema(obj)
        schema = GrapeOAS::ApiModel::Schema.new(type: "object")
        obj.each do |key, value|
          case value
          when Hash
            schema.add_property(key, hash_to_schema(value))
          when Array
            item_schema = value.first.is_a?(Hash) ? hash_to_schema(value.first) : GrapeOAS::ApiModel::Schema.new(type: "string")
            schema.add_property(key, GrapeOAS::ApiModel::Schema.new(type: "array", items: item_schema))
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
        return "integer" if value == Integer
        return "number" if [Float, BigDecimal].include?(value)
        return "boolean" if [TrueClass, FalseClass].include?(value)
        return "array" if value == Array
        return "object" if value == Hash

        "string"
      end

      def schema_from_types(types_hash, rule_constraints)
        schema = GrapeOAS::ApiModel::Schema.new(type: "object")
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
          schema = GrapeOAS::ApiModel::Schema.new(type: "array", items: items_schema)
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

        schema = case primitive
                 when Array
                   items_schema = member ? schema_for_type(member) : GrapeOAS::ApiModel::Schema.new(type: "string")
                   s = GrapeOAS::ApiModel::Schema.new(type: "array", items: items_schema)
                   apply_array_meta_constraints(s, meta)
                   s
                 when Hash
                   GrapeOAS::ApiModel::Schema.new(type: "object")
                 when Integer
                   GrapeOAS::ApiModel::Schema.new(type: "integer")
                 when Float, BigDecimal
                   GrapeOAS::ApiModel::Schema.new(type: "number")
                 when TrueClass, FalseClass
                   GrapeOAS::ApiModel::Schema.new(type: "boolean")
                 else
                   GrapeOAS::ApiModel::Schema.new(type: "string")
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

      def merge_rule_constraints(schema, rc)
        return unless rc

        schema.enum ||= rc[:enum]
        schema.nullable ||= rc[:nullable]
        schema.min_length ||= rc[:min] if rc[:min]
        schema.max_length ||= rc[:max] if rc[:max]
        schema.minimum ||= rc[:minimum] if rc[:minimum]
        schema.maximum ||= rc[:maximum] if rc[:maximum]
        schema.exclusive_minimum ||= rc[:exclusive_minimum]
        schema.exclusive_maximum ||= rc[:exclusive_maximum]
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
      rescue StandardError
        {}
      end

      def extract_enum_from_core_values(core)
        return unless core.respond_to?(:values)

        vals = core.values
        vals if vals.is_a?(Array)
      rescue StandardError
        nil
      end
    end
  end
end
