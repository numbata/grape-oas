# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS31Schema < OAS3Schema
      private

      def openapi_version
        "3.1.0"
      end

      def nullable_keyword?
        false
      end
    end
  end
end
