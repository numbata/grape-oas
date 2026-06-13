# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser that creates a default success response when no responses are defined.
      # Status code defaults to 201 for POST routes and 200 for all other methods.
      # This is the fallback parser used when no other parsers are applicable.
      class DefaultResponseParser
        include Base

        def applicable?(_route)
          # Always applicable as a fallback
          true
        end

        def parse(route)
          [{
            code: default_success_code(route).to_s,
            message: "Success",
            entity: route.options[:entity],
            headers: nil
          }]
        end
      end
    end
  end
end
