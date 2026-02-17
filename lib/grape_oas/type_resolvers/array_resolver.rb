# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Resolves array types like "[String]", "[Integer]", "[MyApp::Types::UUID]".
    #
    # Grape converts `type: [SomeClass]` to the string "[SomeClass]" for documentation.
    # This resolver:
    # 1. Detects the array pattern via regex
    # 2. Extracts the inner type name
    # 3. Attempts to resolve it back to the actual class via Object.const_get
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

      # Pattern to match Grape's array notation: "[Type]" or "[Module::Type]"
      # Intentionally narrow: avoid treating multi-type strings like "[String, Integer]" as arrays.
      ARRAY_PATTERN = /\A\[(?<inner>(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*)\]\z/

      class << self
        def handles?(type)
          return false unless type.is_a?(String)

          type.match?(ARRAY_PATTERN)
        end

        def build_schema(type)
          inner_type_name = extract_inner_type(type)
          return nil unless inner_type_name

          # Try to resolve the string to an actual class
          resolved_class = resolve_class(inner_type_name)

          items_schema = if resolved_class
                           build_schema_from_class(resolved_class)
                         else
                           build_schema_from_string(inner_type_name)
                         end

          ApiModel::Schema.new(
            type: Constants::SchemaTypes::ARRAY,
            items: items_schema,
          )
        end

        private

        def extract_inner_type(type)
          match = type.match(ARRAY_PATTERN)
          match[:inner] if match
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
          format = infer_format_from_name(type_name)

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
