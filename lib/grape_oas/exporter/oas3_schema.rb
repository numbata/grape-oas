# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS3Schema
      def initialize(api_model:)
        @api = api_model
      end

      def generate
        {}
      end
    end
  end
end
