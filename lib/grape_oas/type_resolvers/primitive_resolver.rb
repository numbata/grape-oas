# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Resolves primitive types like "Integer", "String", "Boolean", "Float".
    #
    # This is the fallback resolver that handles basic Ruby types and their
    # string representations. It's registered last in the resolver chain.
    #
    class PrimitiveResolver
      extend Base

      # Known primitive type mappings
      PRIMITIVES = {
        "String" => { type: Constants::SchemaTypes::STRING },
        "Integer" => { type: Constants::SchemaTypes::INTEGER, format: "int32" },
        "Float" => { type: Constants::SchemaTypes::NUMBER, format: "float" },
        "BigDecimal" => { type: Constants::SchemaTypes::NUMBER, format: "double" },
        "Numeric" => { type: Constants::SchemaTypes::NUMBER },
        "Boolean" => { type: Constants::SchemaTypes::BOOLEAN },
        "Grape::API::Boolean" => { type: Constants::SchemaTypes::BOOLEAN },
        "TrueClass" => { type: Constants::SchemaTypes::BOOLEAN },
        "FalseClass" => { type: Constants::SchemaTypes::BOOLEAN },
        "Date" => { type: Constants::SchemaTypes::STRING, format: "date" },
        "DateTime" => { type: Constants::SchemaTypes::STRING, format: "date-time" },
        "Time" => { type: Constants::SchemaTypes::STRING, format: "date-time" },
        "Hash" => { type: Constants::SchemaTypes::OBJECT },
        "Array" => { type: Constants::SchemaTypes::ARRAY },
        "File" => { type: Constants::SchemaTypes::FILE },
        "Rack::Multipart::UploadedFile" => { type: Constants::SchemaTypes::FILE },
        "Symbol" => { type: Constants::SchemaTypes::STRING }
      }.freeze

      class << self
        def handles?(type)
          type_str = normalize_type(type)
          PRIMITIVES.key?(type_str) || resolvable_to_primitive?(type)
        end

        def build_schema(type)
          type_str = normalize_type(type)

          # Check direct mapping first
          if PRIMITIVES.key?(type_str)
            mapping = PRIMITIVES[type_str]
            return ApiModel::Schema.new(
              type: mapping[:type],
              format: mapping[:format],
            )
          end

          # Try to resolve and build schema
          resolved = resolve_class(type_str)
          if resolved
            build_from_resolved(resolved)
          else
            # Default fallback
            ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          end
        end

        private

        def normalize_type(type)
          case type
          when Class
            type.name
          when String
            type
          else
            type.to_s
          end
        end

        def resolvable_to_primitive?(type)
          resolved = resolve_class(normalize_type(type))
          return false unless resolved

          # Dry::Types should be handled by DryTypeResolver.
          return false if resolved.respond_to?(:primitive)

          resolved_name = resolved.respond_to?(:name) ? resolved.name : resolved.to_s
          return false if resolved_name.nil? || resolved_name.empty?

          PRIMITIVES.key?(resolved_name)
        end

        def build_from_resolved(klass)
          # Find mapping by class name
          type_str = klass.name
          mapping = PRIMITIVES[type_str]

          if mapping
            ApiModel::Schema.new(
              type: mapping[:type],
              format: mapping[:format],
            )
          else
            ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
          end
        end
      end
    end
  end
end
