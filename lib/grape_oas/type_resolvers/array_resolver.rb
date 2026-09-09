# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Resolves array types like "[String]", "Array[Integer]", "Set[String, Integer]".
    #
    # Grape converts `type: [SomeClass]` to the string "[SomeClass]" for documentation.
    # Grape 3.3+ VariantCollectionCoercer#to_s emits "Array[Type, ...]" / "Set[Type, ...]"
    # for `type: Array[Integer, String]` so documentation tools can tell a collection
    # of variant members from `types: [Integer, String]` (a scalar oneOf, grape#2758).
    #
    # This resolver:
    # 1. Detects the array pattern via regex
    # 2. Extracts the inner type name(s)
    # 3. Attempts to resolve each name back to the actual class via Object.const_get
    # 4. If resolved, extracts rich metadata (Dry::Types format, primitive, etc.)
    # 5. Falls back to string-based inference if class not available
    #
    # @example Resolving a Dry::Type array
    #   # Input: "[MyApp::Types::UUID]" (string from Grape)
    #   # Resolution: Object.const_get("MyApp::Types::UUID") -> Dry::Type
    #   # Output: Schema(type: "array", items: Schema(type: "string", format: "uuid"))
    #
    class ArrayResolver
      extend Base

      TYPED_ARRAY_PATTERN = Constants::TypePatterns::TYPED_ARRAY
      VARIANT_COLLECTION_PATTERN = Constants::TypePatterns::VARIANT_COLLECTION

      class << self
        def handles?(type)
          return false unless type.is_a?(String)

          type.match?(TYPED_ARRAY_PATTERN) || type.match?(VARIANT_COLLECTION_PATTERN)
        end

        def build_schema(type)
          container, type_names = extract_collection(type)
          return nil unless type_names

          items_schema = build_items_schema(type_names)
          schema = ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: items_schema,
          )
          schema.unique_items = true if container == "Set"
          schema
        end

        private

        def extract_collection(type)
          if (match = type.match(VARIANT_COLLECTION_PATTERN))
            [match[:container], match[:inner].split(/,\s*/)]
          elsif (match = type.match(TYPED_ARRAY_PATTERN))
            [match[:container], [match[:inner]]]
          end
        end

        def build_items_schema(type_names)
          if Constants.nullable_type_pair?(type_names)
            schema = build_items_for_name(type_names.find { |name| !Constants.nil_type?(name) })
            schema.nullable = true
            return schema
          end

          return build_items_for_name(type_names.first) if type_names.size == 1

          has_nil_type = type_names.any? { |name| Constants.nil_type?(name) }
          variants = type_names.reject { |name| Constants.nil_type?(name) }.map { |name| build_items_for_name(name) }
          ApiModel::Schema.new(one_of: variants, nullable: has_nil_type ? true : nil)
        end

        def build_items_for_name(type_name)
          resolved_class = resolve_class(type_name)
          if resolved_class
            build_schema_from_class(resolved_class)
          else
            build_schema_from_string(type_name)
          end
        end

        def build_schema_from_class(klass)
          # First, check if Introspectors can handle this class
          # (e.g., Grape::Entity, Dry::Schema, custom types)
          return GrapeOAS.introspectors.build_schema(klass, stack: [], registry: {}) if GrapeOAS.introspectors.handles?(klass)

          # Delegate Dry::Types (including constrained wrappers) to DryTypeResolver
          return DryTypeResolver.build_schema(klass) if DryTypeResolver.handles?(klass)

          build_primitive_schema(klass)
        end

        def build_primitive_schema(klass)
          schema_type = primitive_to_schema_type(klass)
          format = Constants.format_for_type(klass) || infer_format_from_name(klass.name.to_s)

          ApiModel::Schema.new(
            type: schema_type,
            format: format,
          )
        end

        def build_schema_from_string(type_name)
          # Can't resolve class - fall back to string parsing
          schema_type = string_to_schema_type(type_name)
          format = Constants.format_for_type(type_name) || infer_format_from_name(type_name)

          ApiModel::Schema.new(
            type: schema_type,
            format: format,
          )
        end

        def string_to_schema_type(type_name)
          normalized = type_name.split("::").last&.downcase

          case normalized
          when "integer", "int" then Constants::SchemaTypes::INTEGER
          when "float", "double", "number", "bigdecimal" then Constants::SchemaTypes::NUMBER
          when "boolean", "bool" then Constants::SchemaTypes::BOOLEAN
          when "hash", "object" then Constants::SchemaTypes::OBJECT
          when "array" then Constants::SchemaTypes::ARRAY
          else
            Constants::SchemaTypes::STRING
          end
        end
      end
    end
  end
end
