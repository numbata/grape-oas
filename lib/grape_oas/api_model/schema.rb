# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents a schema object in the DTO model for OpenAPI v2/v3.
    # Used to describe data types, properties, and structure for parameters, request bodies, and responses.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Parameter, GrapeOAS::ApiModel::RequestBody
    class Schema < Node
      VALID_ATTRIBUTES = %i[
        canonical_name type format properties items description
        required nullable enum additional_properties unevaluated_properties defs
        examples extensions
        min_length max_length pattern
        minimum maximum exclusive_minimum exclusive_maximum
        min_items max_items
        discriminator all_of one_of any_of
      ].freeze

      attr_accessor(*VALID_ATTRIBUTES)

      def initialize(**attrs)
        super()

        @properties = {}
        @required = []
        @nullable = false
        @enum = nil
        @additional_properties = nil
        @unevaluated_properties = nil
        @defs = {}
        @discriminator = nil
        @all_of = nil
        @one_of = nil
        @any_of = nil

        attrs.each do |k, v|
          unless VALID_ATTRIBUTES.include?(k)
            raise ArgumentError, "Unknown Schema attribute: #{k}. Valid attributes: #{VALID_ATTRIBUTES.join(", ")}"
          end

          public_send("#{k}=", v)
        end
      end

      def empty?
        @properties.nil? || @properties.empty?
      end

      def add_property(name, schema, required: false)
        @properties[name.to_s] = schema
        @required << name.to_s if required
        schema
      end
    end
  end
end
