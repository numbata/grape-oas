# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Operation
        def initialize(op, ref_tracker = nil, nullable_keyword: true)
          @op = op
          @ref_tracker = ref_tracker
          @nullable_keyword = nullable_keyword
        end

        def build
          data = {
            "operationId" => @op.operation_id,
            "summary" => @op.summary,
            "description" => @op.description,
            "deprecated" => @op.deprecated,
            "tags" => @op.tag_names,
            "parameters" => Parameter.new(@op, @ref_tracker, nullable_keyword: @nullable_keyword).build,
            "requestBody" => RequestBody.new(@op.request_body, @ref_tracker, nullable_keyword: @nullable_keyword).build,
            "responses" => Response.new(@op.responses, @ref_tracker, nullable_keyword: @nullable_keyword).build
          }.compact

          data["security"] = @op.security unless @op.security.nil? || @op.security.empty?

          data.merge!(@op.extensions) if @op.extensions&.any?

          data
        end
      end
    end
  end
end
