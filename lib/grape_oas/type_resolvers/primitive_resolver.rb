# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Resolves primitive types like "Integer", "String", "Boolean", "Float".
    #
    # Handles basic Ruby types and their string representations, including
    # OpenAPI type name aliases via Constants. Registered before the
    # catch-all DefaultResolver in the resolver chain.
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
          !find_mapping(type).nil?
        end

        def build_schema(type)
          schema_type, format = find_mapping(type)
          return nil unless schema_type

          ApiModel::Schema.new(type: schema_type, format: format)
        end

        private

        # Single lookup used by both handles? and build_schema.
        # Returns [type, format] or nil.
        def find_mapping(type)
          type_str = normalize_type(type)

          if (mapping = PRIMITIVES[type_str])
            return [mapping[:type], mapping[:format]]
          end

          # OpenAPI type name aliases ("object", "number", "boolean")
          schema_type = Constants.primitive_type(type_str)
          return [schema_type, Constants.format_for_type(type_str)] if schema_type

          mapping = resolved_primitive_mapping(resolve_class(type_str))
          [mapping[:type], mapping[:format]] if mapping
        end

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

        def resolved_primitive_mapping(resolved)
          return nil unless resolved
          return nil if resolved.respond_to?(:primitive) # Dry::Types handled by DryTypeResolver

          resolved_name = resolved.respond_to?(:name) ? resolved.name : nil
          return nil if resolved_name.nil? || resolved_name.empty?

          PRIMITIVES[resolved_name]
        end
      end
    end
  end
end
