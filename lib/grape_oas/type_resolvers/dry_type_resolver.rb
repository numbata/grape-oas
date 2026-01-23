# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Resolves standalone Dry::Types (not wrapped in arrays).
    #
    # Handles types like "MyApp::Types::UUID" which Grape stringifies.
    # Attempts to resolve the string back to the actual Dry::Type class
    # and extract rich metadata:
    # - Primitive type (String, Integer, etc.)
    # - Format from meta or inferred from name
    # - Constraints (if applicable)
    #
    # @example
    #   # Input: "MyApp::Types::UUID" (string from Grape)
    #   # Resolution: Object.const_get -> Dry::Type with primitive=String
    #   # Output: Schema(type: "string", format: "uuid")
    #
    class DryTypeResolver
      extend Base

      class << self
        def handles?(type)
          # Handle actual Dry::Type objects
          return true if dry_type?(type)

          # Handle strings that resolve to Dry::Types
          return false unless type.is_a?(String)
          return false if type.match?(/\A\[.+\]\z/) # Skip arrays, handled by ArrayResolver

          resolved = resolve_class(type)
          dry_type?(resolved)
        end

        def build_schema(type)
          dry_type = if dry_type?(type)
                       type
                     else
                       resolve_class(type)
                     end

          return nil unless dry_type?(dry_type)

          build_dry_type_schema(dry_type)
        end

        private

        def dry_type?(obj)
          return false unless obj

          obj.respond_to?(:primitive) || obj.respond_to?(:type)
        end

        def build_dry_type_schema(dry_type)
          # Unwrap constrained types to get the core type
          core_type = unwrap_type(dry_type)

          primitive = core_type.respond_to?(:primitive) ? core_type.primitive : String
          schema_type = primitive_to_schema_type(primitive)
          format = extract_format(dry_type)

          schema = ApiModel::Schema.new(
            type: schema_type,
            format: format,
          )

          # Extract enum values if present
          if dry_type.respond_to?(:values)
            values = begin
              dry_type.values
            rescue NoMethodError
              nil
            end
            schema.enum = values if values.is_a?(Array)
          end

          # Check for nullable
          if dry_type.respond_to?(:optional?) && dry_type.optional?
            schema.nullable = true
          end

          schema
        end

        def unwrap_type(dry_type)
          current = dry_type
          max_depth = 5

          max_depth.times do
            break unless current.respond_to?(:type)

            inner = current.type
            break if inner.equal?(current)

            current = inner
          end

          current
        end

        def extract_format(dry_type)
          # Check meta for explicit format
          if dry_type.respond_to?(:meta)
            meta = dry_type.meta
            return meta[:format] if meta[:format]
          end

          # Infer format from type name
          type_name = extract_type_name(dry_type)
          infer_format_from_name(type_name)
        end

        def extract_type_name(dry_type)
          if dry_type.respond_to?(:name) && dry_type.name
            dry_type.name.to_s
          else
            dry_type.to_s
          end
        end

        def infer_format_from_name(name)
          return "uuid" if name.include?("UUID")
          return "date-time" if name.include?("DateTime")
          return "date" if name.include?("Date") && !name.include?("DateTime")
          return "email" if name.include?("Email")
          return "uri" if name.include?("URI") || name.include?("Url")

          nil
        end

        def primitive_to_schema_type(klass)
          case klass.to_s
          when "Integer" then Constants::SchemaTypes::INTEGER
          when "Float", "BigDecimal" then Constants::SchemaTypes::NUMBER
          when "TrueClass", "FalseClass" then Constants::SchemaTypes::BOOLEAN
          when "Hash" then Constants::SchemaTypes::OBJECT
          when "Array" then Constants::SchemaTypes::ARRAY
          when "NilClass" then Constants::SchemaTypes::STRING # nullable handled separately
          else
            Constants::SchemaTypes::STRING
          end
        end
      end
    end
  end
end
