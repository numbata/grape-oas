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

          # Merge extensions
          data.merge!(@op.extensions) if @op.extensions&.any?

          data.compact
        end

        private

        # Common fields present in both OAS2 and OAS3
        def build_common_fields
          {
            "operationId" => @op.operation_id,
            "summary" => @op.summary,
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
      end
    end
  end
end
