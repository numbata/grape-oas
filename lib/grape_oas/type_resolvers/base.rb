# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Base module that defines the interface for all type resolvers.
    #
    # == Why TypeResolvers Exist
    #
    # Grape stores parameter types as strings for documentation purposes.
    # When you declare `type: [MyApp::Types::UUID]` in Grape, it gets stored as
    # the string "[MyApp::Types::UUID]" in route.params. This happens in
    # Grape::Validations::ParamsDocumentation::TypeCache which calls `type.to_s`
    # for memory optimization (singleton cache avoids repeated string allocations).
    #
    # == Why Not Direct Grape Access?
    #
    # While the original type IS preserved in Grape's CoerceValidator
    # (accessible via `endpoint.send(:validations)`), this approach has drawbacks:
    #
    # 1. **Protected API**: `validations` is a protected method, requiring `send`
    # 2. **Coupling**: Tight coupling to Grape's internal validator structure
    # 3. **Complexity**: Matching validators to params by name is error-prone
    # 4. **Performance**: Iterating validators for each param is inefficient
    #
    # TypeResolvers provide a cleaner abstraction:
    # - Try to resolve stringified types back to actual classes via `Object.const_get`
    # - Extract rich metadata from resolved types (Dry::Types format, constraints)
    # - Fall back gracefully to string parsing when classes aren't available
    # - Extensible registry allows custom type handling
    #
    # == Implementing a Custom Resolver
    #
    #   class MyCustomTypeResolver
    #     extend GrapeOAS::TypeResolvers::Base
    #
    #     def self.handles?(type)
    #       # Return true if this resolver can handle the type
    #       resolve_class(type)&.ancestors&.include?(MyCustomType)
    #     end
    #
    #     def self.build_schema(type)
    #       # Build and return an ApiModel::Schema
    #     end
    #   end
    #
    #   GrapeOAS.type_resolvers.register(MyCustomTypeResolver)
    #
    module Base
      # Checks if this resolver can handle the given type.
      #
      # @param type [String, Class, Object] The type to check (stringified or actual)
      # @return [Boolean] true if this resolver can handle the type
      def handles?(type)
        raise NotImplementedError, "#{self} must implement .handles?(type)"
      end

      # Builds an OpenAPI schema from the given type.
      #
      # @param type [String, Class, Object] The type to build schema for
      # @return [ApiModel::Schema] The built schema
      def build_schema(type)
        raise NotImplementedError, "#{self} must implement .build_schema(type)"
      end

      # Attempts to resolve a stringified type back to its actual class.
      # Uses Object.const_get for resolution, similar to grape-swagger's approach.
      #
      # @param type [String, Class] The type to resolve
      # @return [Class, nil] The resolved class, or nil if not resolvable
      def resolve_class(type)
        return type if type.is_a?(Class)
        return type if type.respond_to?(:primitive) # Dry::Type

        return nil unless type.is_a?(String)
        return nil if type.empty?

        Object.const_get(type)
      rescue NameError
        nil
      end

      # Infers OpenAPI format from a type name suffix.
      # Shared across resolvers for consistent format detection.
      #
      # @param name [String] The type name to analyze
      # @return [String, nil] The inferred format or nil
      def infer_format_from_name(name)
        last_segment = name.to_s.split("::").last.to_s
        return nil if last_segment.empty?

        return "uuid" if last_segment.end_with?("UUID")
        return "date-time" if last_segment.end_with?("DateTime")
        return "date" if last_segment.end_with?("Date")
        return "email" if last_segment.end_with?("Email")
        return "uri" if last_segment.end_with?("URI", "Url", "URL")

        nil
      end

      # Converts a Ruby class to its OpenAPI schema type.
      # Shared across resolvers for consistent type mapping.
      #
      # @param klass [Class] The Ruby class
      # @return [String] The OpenAPI schema type
      def primitive_to_schema_type(klass)
        Constants.primitive_type(klass) || Constants::SchemaTypes::STRING
      end
    end
  end
end
