# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser that creates a default 200 response when no responses are defined
      # This is the fallback parser used when no other parsers are applicable
      class DefaultResponseParser
        include Base

        def applicable?(_route)
          # Always applicable as a fallback
          true
        end

        def parse(route)
          inferred = route.options[:default_status]
          inferred ||= route.request_method.to_s.upcase == "POST" ? 201 : 200
          default_code = inferred.to_s

          [{
            code: default_code,
            message: "Success",
            entity: route.options[:entity],
            headers: nil
          }]
        end
      end
    end
  end
end
