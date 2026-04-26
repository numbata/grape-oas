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

        private

        # OAS 3.1: files use JSON Schema content-* keywords instead of
        # the OAS 3.0 `format: binary` convention.
        def apply_file_schema_attributes!(hash)
          hash.delete("format")
          hash["contentMediaType"] = "application/octet-stream"
          hash["contentEncoding"] = "binary"
        end

        # Ensure examples is always an array and recurse into nested schemas
        def normalize_examples!(hash)
          hash["examples"] = [hash["examples"]].compact if hash.key?("examples") && !hash["examples"].is_a?(Array)

          if hash.key?("properties") && hash["properties"].is_a?(Hash)
            hash["properties"].each_value { |v| normalize_examples!(v) if v.is_a?(Hash) }
          end

          return unless hash.key?("items") && hash["items"].is_a?(Hash)

          normalize_examples!(hash["items"])
        end
      end
    end
  end
end
