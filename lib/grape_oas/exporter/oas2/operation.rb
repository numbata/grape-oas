# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      class Operation
        def initialize(op, ref_tracker = nil)
          @op = op
          @ref_tracker = ref_tracker
        end

        def build
          data = {
            "operationId" => @op.operation_id,
            "summary" => @op.summary,
            "description" => @op.description,
            "deprecated" => @op.deprecated,
            "tags" => @op.tag_names,
            "consumes" => ["application/json"],
            "produces" => ["application/json"],
            "parameters" => Parameter.new(@op, @ref_tracker).build,
            "responses" => Response.new(@op.responses, @ref_tracker).build
          }.compact

          data["security"] = @op.security unless @op.security.nil? || @op.security.empty?

          data.merge!(@op.extensions) if @op.extensions&.any?

          data
        end
      end
    end
  end
end
