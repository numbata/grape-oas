# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Response
      include Concerns::ContentTypeResolver
      include Concerns::OasUtilities

      # Default response parsers in priority order
      # DocumentationResponsesParser has highest priority (most comprehensive)
      # HttpCodesParser handles legacy grape-swagger formats
      # DefaultResponseParser is the fallback
      DEFAULT_PARSERS = [
        ResponseParsers::DocumentationResponsesParser,
        ResponseParsers::HttpCodesParser,
        ResponseParsers::DefaultResponseParser
      ].freeze

      class << self
        attr_writer :parsers

        def parsers
          @parsers ||= DEFAULT_PARSERS.dup
        end

        def reset_parsers!
          @parsers = DEFAULT_PARSERS.dup
        end
      end

      attr_reader :api, :route, :app

      def initialize(api:, route:, app: nil)
        @api = api
        @route = route
        @app = app
      end

      def build
        specs = response_specs
        grouped = group_specs_by_status(specs)
        grouped.map { |_code, group_specs| build_response_from_group(group_specs) }
      end

      private

      # Use Strategy pattern to parse responses
      # Parsers are tried in order of priority
      def response_specs
        parser = parsers.find { |p| p.applicable?(route) }
        parser ? parser.parse(route) : []
      end

      def parsers
        @parsers ||= self.class.parsers.map(&:new)
      end

      # Groups specs by status code to support multiple present responses
      def group_specs_by_status(specs)
        specs.group_by { |s| s[:code].to_s }
      end

      # Builds a response from a group of specs with the same status code
      # If any spec has `as:`, build a merged object response using only `as:` entries
      # Else if any spec has `one_of:`, build a oneOf response from one_of entries and
      # any regular specs in the group (this branch only runs when no `as:` entries exist)
      def build_response_from_group(group_specs)
        has_one_of = group_specs.any? { |s| s[:one_of] && !s[:one_of].empty? }
        has_as = group_specs.any? { |s| !s[:as].nil? }

        if has_as
          build_merged_response(group_specs.select { |s| s[:as] })
        elsif has_one_of
          build_one_of_response(group_specs)
        else
          build_response_from_spec(group_specs.first)
        end
      end

      # Builds a oneOf response for multiple possible response schemas
      def build_one_of_response(specs)
        first_spec = specs.first

        all_schemas = []
        specs.each do |spec|
          if spec[:one_of]
            spec[:one_of].each do |one_of_spec|
              one_of_entity = one_of_spec.is_a?(Hash) ? (one_of_spec[:model] || one_of_spec[:entity]) : nil
              raise ArgumentError, "one_of items must include :model or :entity" unless one_of_entity

              is_array = one_of_spec.key?(:is_array) ? one_of_spec[:is_array] : spec[:is_array]
              schema = build_schema(one_of_entity)
              schema = array_schema(schema) if is_array
              all_schemas << schema if schema
            end
          else
            schema = build_schema(spec[:entity])
            schema = array_schema(schema) if spec[:is_array]
            all_schemas << schema if schema
          end
        end

        schema = GrapeOAS::ApiModel::Schema.new(one_of: all_schemas)
        media_types = Array(response_content_types).map do |mime|
          build_media_type(mime_type: mime, schema: schema)
        end

        message = first_spec[:message]
        description = message.is_a?(String) ? message : message&.to_s

        GrapeOAS::ApiModel::Response.new(
          http_status: first_spec[:code].to_s,
          description: description || "Success",
          media_types: media_types,
          headers: normalize_headers(first_spec[:headers]) || headers_from_route,
          extensions: first_spec[:extensions] || extensions_from_route,
          examples: merge_examples(specs),
        )
      end

      # Builds a merged response for multiple present with `as:` keys
      def build_merged_response(specs)
        first_spec = specs.first
        schema = build_merged_schema(specs)
        media_types = Array(response_content_types).map do |mime|
          build_media_type(mime_type: mime, schema: schema)
        end

        message = first_spec[:message]
        description = message.is_a?(String) ? message : message&.to_s

        GrapeOAS::ApiModel::Response.new(
          http_status: first_spec[:code].to_s,
          description: description || "Success",
          media_types: media_types,
          headers: normalize_headers(first_spec[:headers]) || headers_from_route,
          extensions: first_spec[:extensions] || extensions_from_route,
          examples: merge_examples(specs),
        )
      end

      # Builds an object schema with properties from each `as:` keyed spec
      def build_merged_schema(specs)
        properties = {}
        required = []

        specs.each do |spec|
          key = spec[:as].to_s
          entity_schema = build_schema(spec[:entity])

          properties[key] = if spec[:is_array]
                              GrapeOAS::ApiModel::Schema.new(
                                type: Constants::SchemaTypes::ARRAY,
                                items: entity_schema,
                              )
                            else
                              entity_schema
                            end

          required << key if spec[:required]
        end

        GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          properties: properties,
          required: required.empty? ? nil : required,
        )
      end

      # Merges examples from multiple specs
      def merge_examples(specs)
        examples = specs.map { |s| s[:examples] }.compact
        return nil if examples.empty?

        examples.reduce({}, :merge)
      end

      def build_response_from_spec(spec)
        entity_schema = build_schema(spec[:entity])
        schema = wrap_with_root(entity_schema, spec[:entity], is_array: spec[:is_array])
        media_types = Array(response_content_types).map do |mime|
          build_media_type(
            mime_type: mime,
            schema: schema,
          )
        end

        message = spec[:message]
        description = message.is_a?(String) ? message : message&.to_s

        GrapeOAS::ApiModel::Response.new(
          http_status: spec[:code].to_s,
          description: description || "Success",
          media_types: media_types,
          headers: normalize_headers(spec[:headers]) || headers_from_route,
          extensions: spec[:extensions] || extensions_from_route,
          examples: spec[:examples],
        )
      end

      def array_schema(schema)
        GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::ARRAY,
          items: schema,
        )
      end

      def extensions_from_route
        extract_extensions(route.options[:documentation])
      end

      def normalize_headers(hdrs)
        return nil if hdrs.nil?
        return hdrs if hdrs.is_a?(Array)
        return nil unless hdrs.is_a?(Hash)

        hdrs.map { |name, h| build_header_schema(name, h) }
      end

      def headers_from_route
        hdrs = route.options.dig(:documentation, :headers) || route.settings.dig(:documentation, :headers)
        return [] unless hdrs.is_a?(Hash)

        hdrs.map { |name, h| build_header_schema(name, h) }
      end

      # Build a header schema, normalizing field names
      def build_header_schema(name, header_spec)
        {
          name: name,
          schema: {
            "type" => header_spec[:type] || header_spec["type"] || Constants::SchemaTypes::STRING,
            "description" => header_spec[:description] || header_spec["description"] || header_spec[:desc]
          }.compact
        }
      end

      # Build schema for response body
      # Delegates to EntityIntrospector when entity is present
      def build_schema(entity_class)
        return GrapeOAS::ApiModel::Schema.new(type: Constants::SchemaTypes::STRING) unless entity_class

        GrapeOAS.introspectors.build_schema(entity_class, stack: [], registry: {})
      end

      # Wraps schema with root element if configured via route_setting :swagger, root: true/'name'
      def wrap_with_root(schema, entity_class, is_array: false)
        root_setting = route.settings.dig(:swagger, :root)
        return schema unless root_setting

        root_key = derive_root_key(root_setting, entity_class, is_array)
        GrapeOAS::ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          properties: { root_key => schema },
        )
      end

      # Derives the root key name based on the setting
      def derive_root_key(root_setting, entity_class, is_array)
        case root_setting
        when true
          key = entity_name_to_key(entity_class)
          is_array ? pluralize_key(key) : key
        when String, Symbol
          root_setting.to_s
        else
          entity_name_to_key(entity_class)
        end
      end

      # Converts entity class name to underscored key
      def entity_name_to_key(entity_class)
        return "data" unless entity_class

        name = entity_class.is_a?(Class) ? entity_class.name : entity_class.to_s
        # Remove common suffixes like Entity, Serializer
        name = name.split("::").last || name
        name = name.sub(/Entity$/, "").sub(/Serializer$/, "")
        underscore(name)
      end

      def pluralize_key(key)
        pluralize(key)
      end

      def build_media_type(mime_type:, schema:)
        GrapeOAS::ApiModel::MediaType.new(
          mime_type: mime_type,
          schema: schema,
        )
      end

      def response_content_types
        resolve_content_types
      end
    end
  end
end
