# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      # OAS3-specific Paths exporter
      # Inherits common path building logic from Base::Paths
      class Paths < Base::Paths
        private

        # Build OAS3-specific operation with nullable_keyword option
        def build_operation(operation)
          nullable_keyword = @options.key?(:nullable_keyword) ? @options[:nullable_keyword] : true
          Operation.new(operation, @ref_tracker, nullable_keyword: nullable_keyword).build
        end
      end
    end
  end
end
