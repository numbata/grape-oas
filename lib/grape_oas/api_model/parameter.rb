# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents an operation parameter in the DTO model for OpenAPI v2/v3.
    # Used for query, path, header, and cookie parameters in both OpenAPI versions.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Operation
    class Parameter < Node
      attr_accessor :location, :name, :required, :description, :schema, :collection_format, :style, :explode

      def initialize(location:, name:, schema:, required: false, description: nil, collection_format: nil, style: nil,
                     explode: nil)
        super()
        @location = location.to_s
        @name = name
        @required = required
        @schema = schema
        @description = description
        @collection_format = collection_format
        @style = style&.to_s
        @explode = explode
      end
    end
  end
end
