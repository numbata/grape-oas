# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents an operation parameter in the IL for OpenAPI v2/v3.
    # Used for query, path, header, and cookie parameters in both OpenAPI versions.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Operation
    class Parameter < Node
      attr_rw :location, :name, :required, :description, :schema

      def initialize(location:, name:, schema:, required: false, description: nil)
        super()
        @location = location.to_s
        @name = name
        @required = required
        @schema = schema
        @description = description
      end
    end
  end
end
