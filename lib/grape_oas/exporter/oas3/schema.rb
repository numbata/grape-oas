# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Schema
        def initialize(schema, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD)
          @schema = schema
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
        end

        def build
          return {} unless @schema
          return build_all_of_schema if @schema.all_of && !@schema.all_of.empty?
          return build_one_of_schema if @schema.one_of && !@schema.one_of.empty?
          return build_any_of_schema if @schema.any_of && !@schema.any_of.empty?

          schema_hash = build_base_hash
          apply_examples(schema_hash)
          sanitize_enum_against_type(schema_hash)
          apply_extensions_and_extra_properties(schema_hash)
          apply_all_constraints(schema_hash)
          normalize_file_type!(schema_hash)
          schema_hash.compact
        end

        def build_base_hash
          schema_hash = {}
          schema_hash["type"] = nullable_type
          schema_hash["format"] = @schema.format
          schema_hash["description"] = @schema.description.to_s if @schema.description
          apply_nullable(schema_hash)
          props = build_properties(@schema.properties)
          schema_hash["properties"] = props if props
          if @schema.items
            schema_hash["items"] = build_schema_or_ref(@schema.items, include_metadata: false)
            if !schema_hash["description"] && @schema.items.respond_to?(:description) && @schema.items.description
              schema_hash["description"] = @schema.items.description.to_s
            end
            if @schema.items.respond_to?(:canonical_name) && @schema.items.canonical_name &&
               @schema.items.respond_to?(:nullable) && @schema.items.nullable
              case @nullable_strategy
              when Constants::NullableStrategy::KEYWORD
                schema_hash["nullable"] = true
              when Constants::NullableStrategy::EXTENSION
                schema_hash["x-nullable"] = true
              when Constants::NullableStrategy::TYPE_ARRAY
                schema_hash["type"] = (Array(schema_hash["type"]) | ["null"])
              end
            end
          end
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash["enum"] = normalize_enum(@schema.enum, schema_hash["type"], nullable: nullable?) if @schema.enum
          schema_hash["default"] = @schema.default unless @schema.default.nil?
          schema_hash
        end

        def apply_examples(schema_hash)
          return unless @schema.examples

          examples = Array(@schema.examples).map { |ex| coerce_example(ex, schema_hash["type"]) }
          schema_hash["example"] = examples.first
        end

        def apply_extensions_and_extra_properties(schema_hash)
          schema_hash.merge!(@schema.extensions) if @schema.extensions
          schema_hash.delete("properties") if schema_hash["properties"]&.empty? || @schema.type != Constants::SchemaTypes::OBJECT
          schema_hash["additionalProperties"] = @schema.additional_properties unless @schema.additional_properties.nil?
          if @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY
            schema_hash["unevaluatedProperties"] = @schema.unevaluated_properties unless @schema.unevaluated_properties.nil?
            schema_hash["$defs"] = @schema.defs if @schema.defs && !@schema.defs.empty?
          end
          schema_hash["discriminator"] = build_discriminator if @schema.discriminator
        end

        def apply_all_constraints(schema_hash, schema = @schema)
          apply_numeric_constraints(schema_hash, schema)
          apply_string_constraints(schema_hash, schema)
          apply_array_constraints(schema_hash, schema)
        end

        private

        def base_type_for(type)
          type.is_a?(Array) ? (type - ["null"]).first : type
        end

        # Rewrites `type: file` (or `type: ["file", "null"]`) to the
        # version-appropriate representation. Type detection lives here;
        # version-specific attributes are set by `apply_file_schema_attributes!`.
        def normalize_file_type!(hash)
          type = hash["type"]
          if type == Constants::SchemaTypes::FILE
            hash["type"] = Constants::SchemaTypes::STRING
            apply_file_schema_attributes!(hash)
          elsif type.is_a?(Array) && type.include?(Constants::SchemaTypes::FILE)
            hash["type"] = type.map { |t| t == Constants::SchemaTypes::FILE ? Constants::SchemaTypes::STRING : t }
            apply_file_schema_attributes!(hash)
          end
        end

        # OAS 3.0: files are `type: string, format: binary`.
        # OAS 3.1 overrides this with content-* keywords.
        def apply_file_schema_attributes!(hash)
          hash["format"] = "binary"
        end

        # Build allOf schema for inheritance
        def build_all_of_schema
          items = @schema.all_of.map { |item| build_schema_or_ref(item) }
          result = { "allOf" => items }
          apply_composition_attributes(result)
          apply_nullable(result)
          result
        end

        # Build oneOf schema for polymorphism
        def build_one_of_schema
          items = @schema.one_of.map { |item| build_schema_or_ref(item) }
          result = { "oneOf" => items }
          apply_composition_attributes(result)
          result["discriminator"] = build_discriminator if @schema.discriminator
          apply_nullable(result)
          result
        end

        # Build anyOf schema for polymorphism
        def build_any_of_schema
          items = @schema.any_of.map { |item| build_schema_or_ref(item) }
          result = { "anyOf" => items }
          apply_composition_attributes(result)
          result["discriminator"] = build_discriminator if @schema.discriminator
          apply_nullable(result)
          result
        end

        def apply_composition_attributes(result)
          result["type"] = nullable_type if @schema.type
          result["format"] = @schema.format if @schema.format
          result["description"] = @schema.description.to_s if @schema.description
          result["default"] = @schema.default unless @schema.default.nil?
          result["enum"] = normalize_enum(@schema.enum, result["type"], nullable: nullable?) if @schema.enum
          sanitize_enum_against_type(result)
          apply_all_constraints(result)
          result.merge!(@schema.extensions) if @schema.extensions
          normalize_file_type!(result)
          result
        end

        # Build OAS3 discriminator object
        def build_discriminator
          return nil unless @schema.discriminator

          if @schema.discriminator.is_a?(Hash)
            # Already in object format with propertyName and optional mapping
            disc = { "propertyName" => @schema.discriminator[:property_name] || @schema.discriminator["propertyName"] }
            mapping = @schema.discriminator[:mapping] || @schema.discriminator["mapping"]
            disc["mapping"] = mapping if mapping && !mapping.empty?
            disc
          else
            # Simple string - convert to object format
            { "propertyName" => @schema.discriminator.to_s }
          end
        end

        def nullable?
          @schema.respond_to?(:nullable) && !!@schema.nullable
        end

        def nullable_type
          return @schema.type unless nullable? && @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY

          base = Array(@schema.type || Constants::SchemaTypes::STRING)
          (base | ["null"])
        end

        def apply_nullable(schema_hash)
          return unless nullable?

          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            schema_hash["nullable"] = true
          when Constants::NullableStrategy::EXTENSION
            schema_hash["x-nullable"] = true
          end
        end

        def build_properties(properties)
          return nil unless properties
          return nil if properties.empty?

          properties.transform_values do |prop_schema|
            build_schema_or_ref(prop_schema)
          end
        end

        def build_schema_or_ref(schema, include_metadata: true)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = schema.canonical_name.gsub("::", "_")
            ref_hash = { "$ref" => "#/components/schemas/#{ref_name}" }
            return ref_hash unless include_metadata

            result = {}
            result["description"] = schema.description.to_s if schema.description
            result["default"] = schema.default unless schema.default.nil?
            nullable_ref = schema.respond_to?(:nullable) && !!schema.nullable
            result["enum"] = normalize_enum(schema.enum, schema.type, nullable: nullable_ref) if schema.enum
            sanitize_enum_against_type(result, type: schema.type)
            apply_all_constraints(result, schema)
            result.merge!(schema.extensions) if schema.extensions
            apply_nullable_to_ref(result, schema)
            if result.empty?
              ref_hash
            else
              result["allOf"] = [ref_hash]
              result
            end
          else
            # self.class preserves the OAS version subclass (e.g. OAS31::Schema)
            # so nested schemas get version-correct normalization.
            built = self.class.new(schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
            strip_items_metadata(built) unless include_metadata
            built
          end
        end

        def strip_items_metadata(hash)
          hash.delete("description")
        end

        def apply_nullable_to_ref(result, schema)
          return unless schema.respond_to?(:nullable) && schema.nullable

          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            result["nullable"] = true
          when Constants::NullableStrategy::EXTENSION
            result["x-nullable"] = true
          when Constants::NullableStrategy::TYPE_ARRAY
            # TYPE_ARRAY encodes nullability via the "type" field, which cannot be
            # applied to a $ref schema. For refs we intentionally do nothing.
            nil
          end
        end

        def normalize_enum(enum_vals, type, nullable: false)
          return nil unless enum_vals.is_a?(Array)

          nullable ||= type.is_a?(Array) && type.include?("null")
          resolved_type = base_type_for(type)

          coerced = enum_vals.map do |v|
            next v if v.nil?

            case resolved_type
            when Constants::SchemaTypes::INTEGER then v.to_i if v.respond_to?(:to_i)
            when Constants::SchemaTypes::NUMBER then v.to_f if v.respond_to?(:to_f)
            else v
            end
          end
          coerced.compact!
          coerced.push(nil) if nullable && enum_vals.include?(nil)

          result = coerced.uniq
          return nil if result.empty?

          result
        end

        def apply_numeric_constraints(hash, schema = @schema)
          hash["minimum"] = schema.minimum unless schema.minimum.nil?
          hash["maximum"] = schema.maximum unless schema.maximum.nil?

          if @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY
            if schema.exclusive_minimum && !schema.minimum.nil?
              hash["exclusiveMinimum"] = schema.minimum
              hash.delete("minimum")
            end
            if schema.exclusive_maximum && !schema.maximum.nil?
              hash["exclusiveMaximum"] = schema.maximum
              hash.delete("maximum")
            end
          else
            hash["exclusiveMinimum"] = schema.exclusive_minimum if schema.exclusive_minimum
            hash["exclusiveMaximum"] = schema.exclusive_maximum if schema.exclusive_maximum
          end
        end

        def apply_string_constraints(hash, schema = @schema)
          hash["minLength"] = schema.min_length unless schema.min_length.nil?
          hash["maxLength"] = schema.max_length unless schema.max_length.nil?
          hash["pattern"] = schema.pattern if schema.pattern
        end

        def apply_array_constraints(hash, schema = @schema)
          hash["minItems"] = schema.min_items unless schema.min_items.nil?
          hash["maxItems"] = schema.max_items unless schema.max_items.nil?
        end

        # Ensure enum values match the declared type; drop enum if incompatible to avoid invalid specs.
        def sanitize_enum_against_type(hash, type: nil)
          enum_vals = hash["enum"]
          type_val = type || hash["type"]
          return unless enum_vals && type_val

          base = base_type_for(type_val)
          return hash.delete("enum") if base.nil? || base == Constants::SchemaTypes::ARRAY || base == Constants::SchemaTypes::OBJECT

          non_nil_vals = enum_vals.compact

          case base
          when Constants::SchemaTypes::INTEGER
            hash.delete("enum") unless non_nil_vals.all?(Integer)
          when Constants::SchemaTypes::NUMBER
            hash.delete("enum") unless non_nil_vals.all?(Numeric)
          when Constants::SchemaTypes::BOOLEAN
            hash.delete("enum") unless non_nil_vals.all? { |v| v == true || v == false } # rubocop:disable Style/MultipleComparison
          else # string and fallback
            hash.delete("enum") unless non_nil_vals.all?(String)
          end
        end

        def coerce_example(example, type_val)
          case base_type_for(type_val)
          when Constants::SchemaTypes::INTEGER
            example.to_i
          when Constants::SchemaTypes::NUMBER
            example.to_f
          when Constants::SchemaTypes::BOOLEAN
            example == true || example.to_s == "true"
          when Constants::SchemaTypes::STRING, nil
            example.to_s
          else
            example
          end
        end
      end
    end
  end
end
