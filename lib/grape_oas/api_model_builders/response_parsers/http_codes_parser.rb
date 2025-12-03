# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser for responses defined via :http_codes, :failure, or :success options
      # These are legacy grape-swagger formats that we support for compatibility
      class HttpCodesParser
        include Base

        def applicable?(route)
          route.options[:http_codes] || route.options[:failure] || route.options[:success]
        end

        def parse(route)
          specs = []

          specs.concat(parse_option(route, :http_codes)) if route.options[:http_codes]
          specs.concat(parse_option(route, :failure)) if route.options[:failure]
          specs.concat(parse_option(route, :success)) if route.options[:success]

          specs
        end

        private

        def parse_option(route, option_key)
          value = route.options[option_key]
          return [] unless value

          items = value.is_a?(Hash) ? [value] : Array(value)
          items.map { |entry| normalize_entry(entry, route) }
        end

        def normalize_entry(entry, route)
          case entry
          when Hash
            normalize_hash_entry(entry, route)
          when Array
            normalize_array_entry(entry, route)
          else
            normalize_plain_entry(entry, route)
          end
        end

        def normalize_hash_entry(entry, route)
          default_code = (route.options[:default_status] || 200).to_s
          {
            code: extract_status_code(entry, default_code),
            message: extract_description(entry),
            entity: extract_entity(entry, route.options[:entity]),
            headers: entry[:headers],
            examples: entry[:examples],
            as: entry[:as],
            is_array: entry[:is_array] || route.options[:is_array],
            required: entry[:required]
          }
        end

        def normalize_array_entry(entry, route)
          return normalize_plain_entry(nil, route) if entry.empty?

          code, message, entity, examples = entry
          {
            code: code,
            message: message,
            entity: entity || route.options[:entity],
            headers: nil,
            examples: examples
          }
        end

        def normalize_plain_entry(entry, route)
          # Plain status code (e.g., 404)
          {
            code: entry,
            message: nil,
            entity: route.options[:entity],
            headers: nil
          }
        end
      end
    end
  end
end
