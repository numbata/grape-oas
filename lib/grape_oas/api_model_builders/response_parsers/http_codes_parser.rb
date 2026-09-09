# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module ResponseParsers
      # Parser for responses defined via :http_codes, :failure, :success, or
      # :default / :default_response (the OAS "default" catch-all).
      class HttpCodesParser
        include Base

        DEFAULT_RESPONSE_MESSAGE = "Default Response"
        DEFAULT_RESPONSE_CODE = "default"

        def applicable?(route)
          options_applicable?(route) || desc_block?(route)
        end

        def parse(route)
          specs = parse_from_options(route)
          specs = parse_from_desc(route) if specs.empty?
          return specs if specs.any? { |spec| spec[:code].to_s == DEFAULT_RESPONSE_CODE }

          specs + default_response_specs(route)
        end

        def default_response_specs(route)
          data = route.options
          value = default_response_value(data)
          value ||= default_response_value(desc_data(route))
          value ? parse_default_response(value, route) : []
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

          specs = %i[http_codes failure success].flat_map do |key|
            parse_value(data[key], route)
          end
          default_value = data[:default_response] || data[:default]
          return specs unless default_value

          specs.reject { |spec| spec[:code].to_s == DEFAULT_RESPONSE_CODE } +
            parse_default_response(default_value, route)
        end

        # Grape 3.x stores `desc { default ... }` as :default. Grape 4.0
        # (ruby-grape/grape#2861) renamed that key to :default_response and
        # remaps the deprecated `default` alias at write time. Always emit the
        # OAS "default" status — grape-swagger ignores a numeric `code:` here.
        def parse_default_response(value, route)
          entries_for(value).map { |entry| normalize_default_response_entry(entry, route) }
        end

        def normalize_default_response_entry(entry, route)
          if entry.is_a?(Hash)
            entry = normalize_hash_keys(entry)
            {
              code: DEFAULT_RESPONSE_CODE,
              message: extract_description(entry) || DEFAULT_RESPONSE_MESSAGE,
              entity: extract_entity(entry, nil),
              headers: entry[:headers],
              examples: entry[:examples],
              as: entry[:as],
              one_of: normalize_one_of(entry[:one_of]),
              is_array: entry.key?(:is_array) ? entry[:is_array] : route.options[:is_array],
              required: entry[:required]
            }
          else
            {
              code: DEFAULT_RESPONSE_CODE,
              message: DEFAULT_RESPONSE_MESSAGE,
              entity: entry,
              headers: nil,
              is_array: route.options[:is_array]
            }
          end
        end

        def default_response_value(data)
          return unless data.is_a?(Hash)

          data[:default_response] || data[:default]
        end

        def normalize_one_of(one_of)
          return one_of unless one_of.is_a?(Array)

          one_of.map { |entry| normalize_hash_keys(entry) }
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
            route.options[:default] || route.options[:default_response] ||
            (entity_hash && (entity_hash[:code] || entity_hash[:model] || entity_hash[:entity] || entity_hash[:one_of]))
        end

        def desc_block?(route)
          data = desc_data(route)
          data && (data[:success] || data[:failure] || data[:http_codes] || data[:entity] ||
            data[:default] || data[:default_response])
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
