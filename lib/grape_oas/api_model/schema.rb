# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents a schema object in the IL for OpenAPI v2/v3.
    # Used to describe data types, properties, and structure for parameters, request bodies, and responses.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Parameter, GrapeOAS::ApiModel::RequestBody
    class Schema < Node
      attr_rw :canonical_name, :type, :format, :properties, :items, :description, :required

      def initialize(**attrs)
        super()

        @properties = []
        attrs.each { |k, v| public_send("#{k}=", v) }
      end

      def empty?
        @properties.empty?
      end

      def add_property(property)
        @properties << property
      end
    end
  end
end
