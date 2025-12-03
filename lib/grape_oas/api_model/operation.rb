# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents an API operation (endpoint action) in the DTO model for OpenAPI v2/v3.
    # Encapsulates HTTP method, parameters, request body, responses, tags, and security.
    # Used as the core unit for both OpenAPIv2 and OpenAPIv3 operation objects.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Path
    class Operation < Node
      attr_accessor :http_method, :operation_id, :summary, :description,
                    :deprecated, :parameters, :request_body,
                    :responses, :tag_names, :security, :extensions,
                    :consumes, :produces, :suppress_default_error_response

      def initialize(http_method:, operation_id: nil, summary: nil, description: nil,
                     deprecated: false, parameters: [], request_body: nil,
                     responses: [], tag_names: [], security: [], extensions: nil,
                     consumes: [], produces: [])
        super()
        @http_method   = http_method.to_s.downcase
        @operation_id  = operation_id
        @summary       = summary
        @description   = description
        @deprecated    = deprecated
        @parameters    = Array(parameters)
        @request_body  = request_body
        @responses     = Array(responses)
        @tag_names     = Array(tag_names)
        @security      = Array(security)
        @extensions    = extensions
        @consumes      = Array(consumes)
        @produces      = Array(produces)
        @suppress_default_error_response = false
      end

      def add_parameter(parameter)
        @parameters << parameter
      end

      def add_parameters(*parameters)
        @parameters.concat(parameters)
      end

      def add_response(response)
        @responses << response
      end

      def response(code)
        @responses.find { |r| r.http_status == code.to_s }
      end
    end
  end
end
