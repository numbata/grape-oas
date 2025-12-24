# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser for responses defined via :http_codes, :failure, or :success options
      # These are legacy grape-swagger formats that we support for compatibility
      class HttpCodesParser
        include Base

        def applicable?(route)
          # Check route.options (current behavior)
          options_applicable = route.options[:http_codes] || route.options[:failure] || route.options[:success] ||
                               (route.options[:entity].is_a?(Hash) && (route.options[:entity][:code] || route.options[:entity][:model]))

          # Check route.settings[:description] (desc block behavior)
          desc_data = route.settings&.dig(:description)
          settings_applicable = desc_data.is_a?(Hash) &&
                                (desc_data[:success] || desc_data[:failure] || desc_data[:http_codes] || desc_data[:entity])

          options_applicable || settings_applicable
        end

        def parse(route)
          specs = parse_from_options(route)
          return specs unless specs.empty?

          parse_from_desc(route)
        end

        private

        def parse_from_options(route)
          specs = parse_values(route.options, route)
          entity_value = route.options[:entity]
          return specs unless entity_value

          return append_entity_spec(specs, entity_value, route) if specs.empty? || desc_block?(route)

          specs
        end

        def parse_from_desc(route)
          desc_data = route.settings&.dig(:description)
          return [] unless desc_data.is_a?(Hash)

          specs = parse_values(desc_data, route)
          specs = append_entity_spec(specs, desc_data[:entity], route) if desc_data[:entity]
          specs
        end

        def parse_values(data, route)
          return [] unless data.is_a?(Hash)

          %i[http_codes failure success].flat_map do |key|
            parse_value(data[key], route)
          end
        end

        def parse_value(value, route)
          return [] unless value

          entries_for(value).map { |entry| normalize_entry(entry, route) }
        end

        def entries_for(value)
          return [value] if value.is_a?(Hash)
          return [] if value.is_a?(Array) && value.empty?
          return value if value.is_a?(Array) && (value.first.is_a?(Hash) || value.first.is_a?(Array))

          [value]
        end

        def desc_block?(route)
          desc_data = route.settings&.dig(:description)
          desc_data.is_a?(Hash) &&
            (desc_data[:success] || desc_data[:failure] || desc_data[:http_codes] || desc_data[:entity])
        end

        def append_entity_spec(specs, entity_value, route)
          entity_spec = build_entity_spec(entity_value, route)
          return specs if specs.any? { |spec| spec[:code].to_i == entity_spec[:code].to_i }

          specs + [entity_spec]
        end

        def build_entity_spec(entity_value, route)
          if entity_value.is_a?(Hash)
            # Hash format: { code: 201, model: Entity, message: "Created" }
            {
              code: entity_value[:code] || 200,
              message: entity_value[:message],
              entity: extract_entity(entity_value, nil),
              headers: entity_value[:headers],
              examples: entity_value[:examples],
              as: entity_value[:as],
              is_array: entity_value[:is_array] || route.options[:is_array],
              required: entity_value[:required]
            }
          else
            # Plain entity class
            {
              code: 200,
              message: nil,
              entity: entity_value,
              headers: nil,
              examples: nil,
              as: nil,
              is_array: route.options[:is_array],
              required: nil
            }
          end
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
            one_of: entry[:one_of],
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
