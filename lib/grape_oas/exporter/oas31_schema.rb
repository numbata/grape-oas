# frozen_string_literal: true

module GrapeOAS
  module Exporter
    class OAS31Schema < OAS3Schema
      private

      def openapi_version
        "3.1.0"
      end

      def build_info
        info = super
        license = if @api.respond_to?(:license) && @api.license
                    @api.license
                  else
                    { "name" => "Proprietary", "identifier" => "UNLICENSED", "url" => "https://grape.local/license" }
                  end
        info["license"] = license
        info
      end

      def schema_builder
        OAS31::Schema
      end

      def nullable_keyword?
        false
      end
    end
  end
end
