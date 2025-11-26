# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      # OAS2-specific Paths exporter
      # Inherits common path building logic from Base::Paths
      class Paths < Base::Paths
        private

        # Build OAS2-specific operation
        def build_operation(op)
          Operation.new(op, @ref_tracker).build
        end
      end
    end
  end
end
