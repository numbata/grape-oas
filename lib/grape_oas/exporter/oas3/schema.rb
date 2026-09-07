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

          end
          schema_hash["required"] = @schema.required if @schema.required && !@schema.required.empty?
          schema_hash["enum"] = normalize_enum(@schema.enum, schema_hash["type"], nullable: nullable?) if @schema.enum
          schema_hash["default"] = @schema.default unless @schema.default.nil?
          schema_hash
        end

        def apply_examples(schema_hash)
          return if @schema.examples.nil?

          type = schema_hash["type"]
          schema_hash["example"] = coerce_example(@schema.examples, type)
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

        def build_schema_or_ref(schema, include_metadata: true)
          if schema.respond_to?(:canonical_name) && schema.canonical_name
            @ref_tracker << schema.canonical_name if @ref_tracker
            ref_name = GrapeOAS.schema_ref_name.call(schema.canonical_name)
            ref_hash = { "$ref" => "#/components/schemas/#{ref_name}" }
            unless include_metadata
              return ref_hash unless schema_nullable?(schema)

              return { "allOf" => [ref_hash] }.tap { |hash| apply_nullable_to_ref(hash, schema) }
            end

            result = {}
            result["description"] = schema.description.to_s if schema.description
            result["default"] = schema.default unless schema.default.nil?
            enum_type = schema.type
            if schema_nullable?(schema) && @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY
              enum_type = Array(enum_type) | ["null"]
            end
            result["enum"] = normalize_enum(schema.enum, enum_type, nullable: schema_nullable?(schema)) if schema.enum
            sanitize_enum_against_type(result, type: schema.type)
            apply_all_constraints(result, schema)
            result.merge!(schema.extensions) if schema.extensions
            if result.empty? && !schema_nullable?(schema)
              ref_hash
            else
              result["allOf"] = [ref_hash]
              apply_nullable_to_ref(result, schema)
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

        private

        # Returns the primary non-null type from a type value.
        # Assumes at most one non-null type in the array (e.g. ["integer", "null"]).
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
          apply_composition_extensions(result)
          normalize_file_type!(result)
          result
        end

        def apply_composition_extensions(result)
          return unless @schema.extensions

          extensions = @schema.extensions.reject do |key, _value|
            (key == "x-anyOf" && result.key?("anyOf")) ||
              (key == "x-oneOf" && result.key?("oneOf"))
          end
          result.merge!(extensions)
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

        def schema_nullable?(schema)
          schema.respond_to?(:nullable) && !!schema.nullable
        end

        def nullable?
          schema_nullable?(@schema)
        end

        def nullable_type
          return @schema.type unless nullable? && @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY

          base = Array(@schema.type || Constants::SchemaTypes::STRING)
          (base | ["null"])
        end

        def apply_nullable(schema_hash)
          return unless nullable?

          composition_key = %w[allOf oneOf anyOf].find { |k| schema_hash.key?(k) }
          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            if composition_key
              apply_keyword_null_union(schema_hash, composition_key)
            elsif schema_hash["type"]
              schema_hash["nullable"] = true
            end
          when Constants::NullableStrategy::EXTENSION
            schema_hash["x-nullable"] = true
          when Constants::NullableStrategy::TYPE_ARRAY
            if composition_key
              apply_null_union(schema_hash, composition_key, { "type" => "null" })
            else
              schema_hash["type"] = (Array(schema_hash["type"]) | ["null"])
            end
          end
        end

        # Nullable must accompany a type, and every composition constraint must
        # also admit null. The enum keeps the extra branch from allowing objects.
        def apply_keyword_null_union(hash, key)
          hash["nullable"] = true if hash["type"]
          apply_null_union(hash, key, keyword_null_only_branch)
        end

        def apply_null_union(hash, key, null_branch)
          raise ArgumentError, "#{key} must be an Array of schemas" unless hash[key].is_a?(Array)

          branch = { key => hash.delete(key) }
          branch["discriminator"] = hash.delete("discriminator") if hash.key?("discriminator")
          hash["anyOf"] = [branch, null_branch]
        end

        def build_properties(properties)
          return nil unless properties
          return nil if properties.empty?

          properties.transform_values do |prop_schema|
            build_schema_or_ref(prop_schema)
          end
        end

        def strip_items_metadata(hash)
          hash.delete("description")
        end

        def apply_nullable_to_ref(result, schema)
          return unless schema_nullable?(schema)

          case @nullable_strategy
          when Constants::NullableStrategy::KEYWORD
            apply_ref_null_union(result, keyword_null_only_branch, typed_nullable: true)
          when Constants::NullableStrategy::EXTENSION
            result["x-nullable"] = true
          when Constants::NullableStrategy::TYPE_ARRAY
            apply_ref_null_union(result, { "type" => "null" }, typed_nullable: false)
          end
        end

        # Prefer a bare $ref as the non-null alternative when allOf would only
        # wrap that single ref (OAS 3.0 needs allOf only for $ref siblings).
        def apply_ref_null_union(result, null_branch, typed_nullable:)
          allof = result["allOf"]
          if bare_single_ref_allof?(allof)
            ref = result.delete("allOf").first
            result["nullable"] = true if typed_nullable && result["type"]
            result["anyOf"] = [ref, null_branch]
          elsif typed_nullable
            apply_keyword_null_union(result, "allOf")
          else
            apply_null_union(result, "allOf", null_branch)
          end
        end

        def bare_single_ref_allof?(allof)
          allof.is_a?(Array) && allof.size == 1 && allof.first.is_a?(Hash) && allof.first.keys == ["$ref"]
        end

        def keyword_null_only_branch
          { "type" => Constants::SchemaTypes::OBJECT, "nullable" => true, "enum" => [nil] }
        end

        def normalize_enum(enum_vals, type, nullable: false)
          return nil unless enum_vals.is_a?(Array)

          nullable = (nullable || (type.is_a?(Array) && type.include?(Constants::SchemaTypes::NULL))) &&
                     enum_null_supported?(type)
          resolved_type = base_type_for(type)

          has_nil = nullable && enum_vals.include?(nil)

          result = enum_vals.each_with_object([]) do |v, acc|
            next if v.nil?

            coerced_v = case resolved_type
                        when Constants::SchemaTypes::INTEGER then v.to_i if v.respond_to?(:to_i)
                        when Constants::SchemaTypes::NUMBER then v.to_f if v.respond_to?(:to_f)
                        else v
                        end
            acc << coerced_v unless coerced_v.nil?
          end

          result.uniq!
          result.push(nil) if has_nil
          return nil if result.empty?

          result
        end

        def enum_null_supported?(type)
          return true if @nullable_strategy == Constants::NullableStrategy::KEYWORD

          @nullable_strategy == Constants::NullableStrategy::TYPE_ARRAY &&
            type.is_a?(Array) && type.include?(Constants::SchemaTypes::NULL)
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
          hash["uniqueItems"] = true if schema.unique_items
        end

        # Ensure enum values match the declared type; drop enum if incompatible to avoid invalid specs.
        def sanitize_enum_against_type(hash, type: nil)
          # A literal `"enum" => nil` (from a nil-only enum on a non-nullable schema) must not
          # survive: composition/$ref callers never `.compact` their result hash, so an unguarded
          # nil would leak as `enum: null` and, for $ref, would make `result.empty?` false and
          # force an unwanted `allOf` wrapper.
          return hash.delete("enum") if hash.key?("enum") && hash["enum"].nil?

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
          return nil if example.nil?

          base_type = base_type_for(type_val)
          case base_type
          when Constants::SchemaTypes::ARRAY
            return example if example.is_a?(Array)

            return nil
          when Constants::SchemaTypes::OBJECT
            return example if example.is_a?(Hash)

            return nil
          when nil
            return example
          else
            return nil if example.is_a?(Hash)

            if example.is_a?(Array)
              return nil unless example.size == 1

              example = example.first
            end
          end

          case base_type
          when Constants::SchemaTypes::INTEGER
            coerce_integer_example(example)
          when Constants::SchemaTypes::NUMBER
            coerce_number_example(example)
          when Constants::SchemaTypes::BOOLEAN
            case example
            when true, false
              example
            when String
              return true if example.casecmp("true").zero?
              return false if example.casecmp("false").zero?

              nil
            end
          when Constants::SchemaTypes::STRING
            example.to_s
          else
            example
          end
        end

        def coerce_integer_example(example)
          example.is_a?(String) ? Integer(example, 10) : Integer(example)
        rescue ArgumentError, TypeError
          nil
        end

        def coerce_number_example(example)
          Float(example)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
