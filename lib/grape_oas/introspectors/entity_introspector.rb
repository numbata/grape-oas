# frozen_string_literal: true

require_relative "../api_model_builders/concerns/type_resolver"

module GrapeOAS
  module Introspectors
    class EntityIntrospector
      include GrapeOAS::ApiModelBuilders::Concerns::TypeResolver

      def initialize(entity_class, stack: [], registry: {})
        @entity_class = entity_class
        @stack = stack
        @registry = registry
      end

      def build_schema
        pushed = false

        # Return cached schema (already built) if present
        built = @registry[@entity_class]
        return built if built && !built.properties.empty?

        # Build (or reuse placeholder) for this entity
        schema = (@registry[@entity_class] ||= ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          canonical_name: @entity_class.name,
          description: nil,
          nullable: nil,
        ))

        if @stack.include?(@entity_class)
          schema.description ||= "Cycle detected while introspecting"
          return schema
        end

        @stack << @entity_class
        pushed = true
        doc = entity_doc

        schema.description ||= extract_description(doc)
        schema.nullable = extract_nullable(doc) if schema.nullable.nil?

        # Apply entity-level schema properties from documentation
        apply_entity_level_properties(schema, doc)

        root_ext = doc.select { |k, _| k.to_s.start_with?("x-") }
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

          prop_schema = ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: prop_schema) if is_array

          schema.add_property(name, prop_schema, required: doc[:required])
        end

        schema
      ensure
        @stack.pop if pushed
      end

      private

      def entity_doc
        @entity_class.respond_to?(:documentation) ? (@entity_class.documentation || {}) : {}
      rescue NoMethodError
        {}
      end

      def exposures
        return [] unless @entity_class.respond_to?(:root_exposures)

        root = @entity_class.root_exposures
        list = root.instance_variable_get(:@exposures) || []
        Array(list)
      rescue NoMethodError
        []
      end

      # rubocop:disable Metrics/AbcSize
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
                   ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: inner)
                 when Hash
                   ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
                 else
                   schema_for_type(type)
                 end
        schema ||= ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
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

        # Apply numeric constraints
        schema.minimum = doc[:minimum] if doc.key?(:minimum) && schema.respond_to?(:minimum=)
        schema.maximum = doc[:maximum] if doc.key?(:maximum) && schema.respond_to?(:maximum=)

        # Apply string constraints
        schema.min_length = doc[:min_length] if doc.key?(:min_length) && schema.respond_to?(:min_length=)
        schema.max_length = doc[:max_length] if doc.key?(:max_length) && schema.respond_to?(:max_length=)
        schema.pattern = doc[:pattern] if doc.key?(:pattern) && schema.respond_to?(:pattern=)

        schema
      end
      # rubocop:enable Metrics/AbcSize

      def exposed?(exposure)
        conditions = exposure.instance_variable_get(:@conditions) || []
        return true if conditions.empty?

        # If conditional exposure, keep it but mark nullable to reflect optionality
        true
      rescue NoMethodError
        true
      end

      def conditional?(exposure)
        conditions = exposure.instance_variable_get(:@conditions) || []
        !conditions.empty?
      rescue NoMethodError
        false
      end

      def schema_for_type(type)
        case type
        when nil
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        when Class
          if defined?(Grape::Entity) && type <= Grape::Entity
            self.class.new(type, stack: @stack, registry: @registry).build_schema
          else
            build_schema_for_primitive(type)
          end
        when String, Symbol
          # First try to resolve as entity class name
          entity_class = resolve_entity_from_string(type.to_s)
          if entity_class
            self.class.new(entity_class, stack: @stack, registry: @registry).build_schema
          else
            # Fall back to primitive type lookup
            schema_type = Constants.primitive_type(type) || Constants::SchemaTypes::STRING
            ApiModel::Schema.new(type: schema_type)
          end
        else
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        end
      end

      # Attempts to resolve a string type name to a Grape::Entity class.
      def resolve_entity_from_string(type_name)
        return nil unless defined?(Grape::Entity)

        klass = Object.const_get(type_name)
        klass if klass.is_a?(Class) && klass <= Grape::Entity
      rescue NameError
        nil
      end

      def schema_for_merge(exposure, doc)
        using_class = resolve_entity_from_opts(exposure, doc)
        return ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT) unless using_class

        child = self.class.new(using_class, stack: @stack, registry: @registry).build_schema
        merged = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
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
        merge_flag = extract_merge_flag(exposure, doc, opts)
        merge_flag && resolve_entity_from_opts(exposure, doc)
      end

      # Extract description from hash, supporting multiple key names
      def extract_description(hash)
        hash[:description] || hash[:desc]
      end

      # Extract nullable flag from documentation
      def extract_nullable(doc)
        doc[:nullable] || doc["nullable"] || false
      end

      # Apply entity-level schema properties (additional_properties, defs, etc.)
      def apply_entity_level_properties(schema, doc)
        schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
        schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)

        defs = doc[:defs] || doc[:$defs]
        schema.defs = defs if defs.is_a?(Hash)
      rescue NoMethodError
        # Silently handle errors when schema doesn't respond to setters
      end

      # Extract merge flag from multiple sources
      def extract_merge_flag(exposure, doc, opts)
        opts[:merge] || doc[:merge] || (exposure.respond_to?(:for_merge) && exposure.for_merge)
      end
    end
  end
end
