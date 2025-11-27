# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module Base
      # Base class for Operation exporters
      # Contains common logic shared between OAS2 and OAS3
      class Operation
        def initialize(operation, ref_tracker = nil, **options)
          @op = operation
          @ref_tracker = ref_tracker
          @options = options
        end

        def build
          data = build_common_fields

          # Add version-specific fields
          data.merge!(build_version_specific_fields)

          # Add security if present
          data["security"] = @op.security unless @op.security.nil? || @op.security.empty?

          # Guarantee a 4xx response for lint rules
          ensure_default_error_response(data)

          # Merge extensions
          data.merge!(@op.extensions) if @op.extensions&.any?

          data.compact
        end

        private

        # Common fields present in both OAS2 and OAS3
        def build_common_fields
          summary = @op.summary
          summary ||= @op.description&.split(/\.\s/)&.first&.strip
          # Fallback: generate a readable summary from the operationId to satisfy lint rules
          if summary.nil? && @op.operation_id
            summary = @op.operation_id
                      .to_s
                      .tr("_", " ")
                      .split
                      .map { |w| w.capitalize }
                      .join(" ")
          end

          {
            "operationId" => @op.operation_id,
            "summary" => summary,
            "description" => @op.description,
            "deprecated" => @op.deprecated,
            "tags" => @op.tag_names
          }
        end

        # Template method - subclasses must implement version-specific fields
        # @return [Hash] Version-specific fields (e.g., consumes/produces for OAS2, requestBody for OAS3)
        def build_version_specific_fields
          raise NotImplementedError, "#{self.class} must implement #build_version_specific_fields"
        end

        # Ensure there is at least one 4xx response when any responses exist
        def ensure_default_error_response(data)
          responses = data["responses"]
          return data unless responses && !responses.empty?

          has_4xx = responses.keys.any? { |code| code.to_s.start_with?("4") }
          return data if has_4xx

          responses["400"] = {
            "description" => "Bad Request"
          }

          data
        end
      end
    end
  end
end
