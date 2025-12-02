# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS2
      # OAS2-specific Operation exporter
      # Inherits common operation logic from Base::Operation
      class Operation < Base::Operation
        private

        # OAS2-specific fields: consumes, produces, parameters (including body)
        def build_version_specific_fields
          {
            "consumes" => consumes,
            "produces" => produces,
            "parameters" => Parameter.new(@op, @ref_tracker).build,
            "responses" => Response.new(@op.responses, @ref_tracker).build
          }
        end

        def consumes
          Array(@op.consumes.presence || [Constants::MimeTypes::JSON])
        end

        def produces
          Array(@op.produces.presence || [Constants::MimeTypes::JSON])
        end
      end
    end
  end
end
