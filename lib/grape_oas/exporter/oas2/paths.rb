# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      # OAS2-specific Paths exporter
      # Inherits common path building logic from Base::Paths
      class Paths < Base::Paths
        private

        # Build OAS2-specific operation
        def build_operation(operation)
          Operation.new(operation, @ref_tracker,
                        nullable_strategy: @options[:nullable_strategy],
                        suppress_default_error_response: @options[:suppress_default_error_response],).build
        end
      end
    end
  end
end
