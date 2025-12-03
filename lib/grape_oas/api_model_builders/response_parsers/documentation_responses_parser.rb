# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser for responses defined in documentation: { responses: { ... } }
      # This is the most comprehensive format and aligns with OpenAPI specification
      class DocumentationResponsesParser
        include Base
        include Concerns::OasUtilities

        def applicable?(route)
          route.options.dig(:documentation, :responses).is_a?(Hash)
        end

        def parse(route)
          doc_resps = route.options.dig(:documentation, :responses)
          return [] unless doc_resps.is_a?(Hash)

          doc_resps.map do |code, doc|
            doc = normalize_hash_keys(doc)
            {
              code: code,
              message: extract_description(doc),
              headers: doc[:headers],
              entity: extract_entity(doc, route.options[:entity]),
              extensions: extract_extensions(doc),
              examples: doc[:examples]
            }
          end
        end
      end
    end
  end
end
