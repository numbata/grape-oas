# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      # OAS3-specific Paths exporter
      # Inherits common path building logic from Base::Paths
      class Paths < Base::Paths
        private

        # Build OAS3-specific operation with nullable_strategy option
        def build_operation(operation)
          Operation.new(operation, @ref_tracker,
                        nullable_strategy: @options[:nullable_strategy] || Constants::NullableStrategy::KEYWORD,
                        suppress_default_error_response: @options[:suppress_default_error_response],).build
        end
      end
    end
  end
end
