# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS31
      # OAS3.1-specific Schema exporter
      # Differs from OAS3 by preferring `examples` over deprecated `example`.
      class Schema < OAS3::Schema
        def openapi_version
          "3.1.0"
        end

        private

        def build
          hash = super

          # swap example -> examples if present
          if hash.key?("example")
            ex = hash.delete("example")
            hash["examples"] ||= ex
          end
          normalize_examples!(hash)
          hash
        end

        # Ensure examples is always an array and recurse into nested schemas
        def normalize_examples!(hash)
          if hash.key?("examples") && !hash["examples"].is_a?(Array)
            hash["examples"] = [hash["examples"]].compact
          end

          if hash.key?("properties") && hash["properties"].is_a?(Hash)
            hash["properties"].each_value { |v| normalize_examples!(v) if v.is_a?(Hash) }
          end

          if hash.key?("items") && hash["items"].is_a?(Hash)
            normalize_examples!(hash["items"])
          end
        end
      end
    end
  end
end
