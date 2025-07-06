# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class RequestParams
      ROUTE_PARAM_REGEX = /(?<=:)\w+/

      PRIMITIVE_TYPE_MAPPING = {
        "float" => "number",
        "bigdecimal" => "number",
        "string" => "string",
        "integer" => "integer",
        "boolean" => "boolean"
      }.freeze

      attr_reader :api, :route

      def initialize(api:, route:)
        @api = api
        @route = route
      end

      def build
        route_params = route.path.scan(ROUTE_PARAM_REGEX)

        body_schema = GrapeOAS::ApiModel::Schema.new(type: "object")
        path_params = []

        (route.options[:params] || {}).each do |name, spec|
          location = route_params.include?(name) ? "path" : extract_location(spec: spec)
          required = spec[:required] || false
          type = sanitize_type(type: spec[:type])

          schema = GrapeOAS::ApiModel::Schema.new(
            type: type,
            required: required,
          )

          if location == "body"
            body_schema.add_property(schema)
          else
            path_params << GrapeOAS::ApiModel::Parameter.new(
              location: location,
              name: name,
              required: required,
              schema: schema,
              description: spec[:documentation]&.dig(:desc),
            )
          end
        end

        [body_schema, path_params]
      end

      private

      def extract_location(spec:, route_params:)
        spec.dig(:documentation, :param_type)&.downcase || "query"
      end

      def sanitize_type(type:)
        PRIMITIVE_TYPE_MAPPING.fetch(type.to_s.downcase, "string")
      end
    end
  end
end
