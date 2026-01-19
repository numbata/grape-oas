# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser for responses defined via :http_codes, :failure, or :success options
      # These are legacy grape-swagger formats that we support for compatibility
      class HttpCodesParser
        include Base

        def applicable?(route)
          options_applicable?(route) || desc_block?(route)
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

          # Append entity from options unless desc block has explicit :success definition
          # that should take precedence (stored via `success({ code: X, model: Y })` syntax)
          should_append = (specs.empty? || desc_block?(route)) && !desc_block_has_explicit_success?(route)
          return append_entity_spec(specs, entity_value, route) if should_append

          specs
        end

        def parse_from_desc(route)
          data = desc_data(route)
          return [] unless data

          specs = parse_values(data, route)
          specs = append_entity_spec(specs, data[:entity], route) if data[:entity]
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

        def desc_data(route)
          data = route.settings&.dig(:description)
          data if data.is_a?(Hash)
        end

        def options_applicable?(route)
          entity_hash = route.options[:entity].is_a?(Hash) ? route.options[:entity] : nil
          route.options[:http_codes] || route.options[:failure] || route.options[:success] ||
            (entity_hash && (entity_hash[:code] || entity_hash[:model] || entity_hash[:entity] || entity_hash[:one_of]))
        end

        def desc_block?(route)
          data = desc_data(route)
          data && (data[:success] || data[:failure] || data[:http_codes] || data[:entity])
        end

        def desc_block_has_explicit_success?(route)
          desc_data(route)&.key?(:success)
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
              one_of: entity_value[:one_of],
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
          when Class, Module
            # Plain entity class (e.g., success TestEntity)
            normalize_entity_entry(entry, route)
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

        def normalize_entity_entry(entity_class, route)
          # Plain entity class (e.g., success TestEntity)
          {
            code: route.options[:default_status] || 200,
            message: nil,
            entity: entity_class,
            headers: nil,
            is_array: route.options[:is_array]
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
