# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      # OAS3-specific Operation exporter
      # Inherits common operation logic from Base::Operation
      class Operation < Base::Operation
        private

        # OAS3-specific fields: parameters (no body), requestBody, responses
        def build_version_specific_fields
          nullable_keyword = @options.key?(:nullable_keyword) ? @options[:nullable_keyword] : true

          {
            "parameters" => Parameter.new(@op, @ref_tracker, nullable_keyword: nullable_keyword).build,
            "requestBody" => RequestBody.new(@op.request_body, @ref_tracker, nullable_keyword: nullable_keyword).build,
            "responses" => Response.new(@op.responses, @ref_tracker, nullable_keyword: nullable_keyword).build
          }
        end
      end
    end
  end
end
