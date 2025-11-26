# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    class EntityIntrospector
      PRIMITIVE_MAPPING = {
        "integer" => "integer",
        "float" => "number",
        "bigdecimal" => "number",
        "string" => "string",
        "boolean" => "boolean"
      }.freeze

      def initialize(entity_class)
        @entity_class = entity_class
      end

      def build_schema
        schema = ApiModel::Schema.new(
          type: "object",
          canonical_name: @entity_class.name,
          description: entity_doc[:desc] || entity_doc[:description],
        )
        root_ext = entity_doc.select { |k, _| k.to_s.start_with?("x-") }
        schema.extensions = root_ext if root_ext.any?

        exposures.each do |exposure|
          next unless exposed?(exposure)

          name = exposure.key.to_s
          doc = exposure.documentation || {}
          opts = exposure.instance_variable_get(:@options) || {}

          if merge_exposure?(exposure, doc, opts)
            merged_schema = schema_for_merge(exposure, doc)
            merged_schema.properties.each do |n, ps|
              schema.add_property(n, ps, required: merged_schema.required.include?(n))
            end
            next
          end

          prop_schema = schema_for_exposure(exposure, doc)
          if conditional?(exposure)
            prop_schema.nullable = true if prop_schema.respond_to?(:nullable=) && !prop_schema.nullable
            doc = doc.merge(required: false)
          end
          is_array = doc[:is_array] || doc["is_array"]

          prop_schema = ApiModel::Schema.new(type: "array", items: prop_schema) if is_array

          schema.add_property(name, prop_schema, required: doc[:required])
        end

        schema
      end

      private

      def entity_doc
        @entity_class.respond_to?(:documentation) ? (@entity_class.documentation || {}) : {}
      rescue StandardError
        {}
      end

      def exposures
        return [] unless @entity_class.respond_to?(:root_exposures)

        root = @entity_class.root_exposures
        list = root.instance_variable_get(:@exposures) || []
        Array(list)
      rescue StandardError
        []
      end

      def schema_for_exposure(exposure, doc)
        opts = exposure.instance_variable_get(:@options) || {}
        type = doc[:type] || doc["type"] || opts[:using]
        nullable = doc[:nullable] || doc["nullable"] || false
        enum = doc[:values] || doc["values"]
        desc = doc[:desc] || doc["desc"]
        fmt  = doc[:format] || doc["format"]
        example = doc[:example] || doc["example"]
        x_ext = doc.select { |k, _| k.to_s.start_with?("x-") }

        schema = case type
                 when Array
                   inner = schema_for_type(type.first)
                   ApiModel::Schema.new(type: "array", items: inner)
                 when Hash
                   ApiModel::Schema.new(type: "object")
                 else
                   schema_for_type(type)
                 end
        schema ||= ApiModel::Schema.new(type: "string")
        schema.nullable = nullable
        schema.enum = enum if enum
        schema.description = desc if desc
        schema.format = fmt if fmt
        schema.examples = example if schema.respond_to?(:examples=) && example
        schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
        schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)
        defs = doc[:defs] || doc[:$defs]
        schema.defs = defs if defs.is_a?(Hash)
        schema.extensions = x_ext if x_ext.any? && schema.respond_to?(:extensions=)
        schema
      end

      def exposed?(exposure)
        conditions = exposure.instance_variable_get(:@conditions) || []
        return true if conditions.empty?

        # If conditional exposure, keep it but mark nullable to reflect optionality
        true
      rescue StandardError
        true
      end

      def conditional?(exposure)
        conditions = exposure.instance_variable_get(:@conditions) || []
        !conditions.empty?
      rescue StandardError
        false
      end

      def schema_for_type(type)
        case type
        when nil
          ApiModel::Schema.new(type: "string")
        when Class
          if defined?(Grape::Entity) && type <= Grape::Entity
            self.class.new(type).build_schema
          elsif type == Integer
            ApiModel::Schema.new(type: "integer")
          elsif [Float, BigDecimal].include?(type)
            ApiModel::Schema.new(type: "number")
          elsif [TrueClass, FalseClass].include?(type)
            ApiModel::Schema.new(type: "boolean")
          elsif type == Array
            ApiModel::Schema.new(type: "array")
          elsif type == Hash
            ApiModel::Schema.new(type: "object")
          else
            ApiModel::Schema.new(type: "string")
          end
        when String, Symbol
          t = PRIMITIVE_MAPPING[type.to_s.downcase] || "string"
          ApiModel::Schema.new(type: t)
        else
          ApiModel::Schema.new(type: "string")
        end
      end

      def schema_for_merge(exposure, doc)
        using_class = resolve_entity_from_opts(exposure, doc)
        return ApiModel::Schema.new(type: "object") unless using_class

        child = self.class.new(using_class).build_schema
        merged = ApiModel::Schema.new(type: "object")
        child.properties.each do |n, ps|
          merged.add_property(n, ps, required: child.required.include?(n))
        end
        merged
      end

      def resolve_entity_from_opts(exposure, doc)
        opts = exposure.instance_variable_get(:@options) || {}
        type = doc[:type] || doc["type"] || opts[:using]
        return type if defined?(Grape::Entity) && type.is_a?(Class) && type <= Grape::Entity

        nil
      end

      def merge_exposure?(exposure, doc, opts)
        merge_flag = opts[:merge] || doc[:merge] || (exposure.respond_to?(:for_merge) && exposure.for_merge)
        merge_flag && resolve_entity_from_opts(exposure, doc)
      end
    end
  end
end
