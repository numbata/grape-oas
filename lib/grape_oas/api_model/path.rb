# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents an API path (endpoint) in the IL for OpenAPI v2/v3.
    # Contains a list of operations (HTTP methods) for the path.
    # Used to build the 'paths' object in both OpenAPIv2 and OpenAPIv3 documents.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Api
    class Path < Node
      attr_rw :template, :operations

      def initialize(template:)
        super()
        @template   = template
        @operations = []
      end

      def add_operation(operation)
        @operations << operation
      end

      def [](method_sym)
        @operations.find { |op| op.http_method.to_sym == method_sym.to_sym }
      end
    end
  end
end
