# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Operation
      attr_reader :api, :route

      def initialize(api:, route:)
        @api = api
        @route = route
      end

      def build
        operation = GrapeOAS::ApiModel::Operation.new(
          http_method: http_method,
          operation_id: operation_id,
          summary: route.options[:description],
          tag_names: tag_names,
          extensions: operation_extensions,
        )

        api.add_tags(*tag_names) if tag_names.any?

        build_request(operation)

        build_responses.each { |resp| operation.add_response(resp) }

        operation.security = build_security if build_security

        operation
      end

      private

      def operation_id
        @operation_id ||= route.options.fetch(:nickname) do
          slug = route
                 .pattern
                 .origin
                 .gsub(/[^a-z0-9]+/i, "_")
                 .gsub(/_+/, "_")
                 .sub(/^_|_$/, "")

          "#{http_method}_#{slug}"
        end
      end

      def http_method
        @http_method ||= route.request_method.downcase.to_sym
      end

      def tag_names
        @tag_names ||= Array(route.options[:tags])
      end

      def build_response
        GrapeOAS::ApiModelBuilders::Response
          .new(api: api, route: route)
          .build
      end

      def build_responses
        Array(build_response)
      end

      def build_security
        route.options.dig(:documentation, :security) ||
          route.options[:security] ||
          route.options[:auth]
      end

      def operation_extensions
        doc = route.options[:documentation]
        return nil unless doc.is_a?(Hash)

        ext = doc.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.empty?
      end

      def build_request(operation)
        GrapeOAS::ApiModelBuilders::Request
          .new(api: api, route: route, operation: operation)
          .build
      end
    end
  end
end
