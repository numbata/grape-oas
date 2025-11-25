# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    class Response
      attr_reader :api, :route

      def initialize(api:, route:)
        @api = api
        @route = route
      end

      def build
        response_specs.map { |spec| build_response_from_spec(spec) }
      end

      private

      def response_specs
        specs = []

        specs.concat(extract_http_codes(route.options[:http_codes])) if route.options[:http_codes]
        specs.concat(extract_http_codes(route.options[:failure])) if route.options[:failure]
        specs.concat(extract_http_codes(route.options[:success])) if route.options[:success]
        specs.concat(extract_doc_responses) if route.options.dig(:documentation, :responses)

        if specs.empty?
          specs << {
            code: default_status_code,
            message: "Success",
            entity: route.options[:entity],
            headers: nil
          }
        end

        specs
      end

      def extract_doc_responses
        doc_resps = route.options.dig(:documentation, :responses)
        return [] unless doc_resps.is_a?(Hash)

        doc_resps.map do |code, doc|
          doc = doc.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
          {
            code: code,
            message: doc[:message] || doc[:description],
            headers: doc[:headers],
            entity: doc[:model] || doc[:entity] || route.options[:entity],
            extensions: doc.select { |k, _| k.to_s.start_with?("x-") },
            examples: doc[:examples]
          }
        end
      end

      def extract_http_codes(value)
        return [] unless value

        items = value.is_a?(Hash) ? [value] : Array(value)

        items.map do |entry|
          if entry.is_a?(Hash)
            {
              code: entry[:code] || entry[:status] || entry[:http_status] || default_status_code,
              message: entry[:message] || entry[:desc] || entry[:description],
              entity: entry[:model] || entry[:entity] || route.options[:entity],
              headers: entry[:headers]
            }
          elsif entry.is_a?(Array)
            code, message, entity = entry
            { code: code, message: message, entity: entity || route.options[:entity], headers: nil }
          else
            { code: entry, message: nil, entity: route.options[:entity], headers: nil }
          end
        end
      end

      def default_status_code
        (route.options[:default_status] || 200).to_s
      end

      def build_response_from_spec(spec)
        schema = build_schema(spec[:entity])
        media_type = build_media_type(
          mime_type: "application/json",
          schema: schema,
        )

        GrapeOAS::ApiModel::Response.new(
          http_status: spec[:code].to_s,
          description: spec[:message] || "Success",
          media_types: [media_type],
          headers: normalize_headers(spec[:headers]) || headers_from_route,
          extensions: spec[:extensions] || extensions_from_route,
          examples: spec[:examples],
        )
      end

      def extensions_from_route
        ext = route.options[:documentation]&.select { |k, _| k.to_s.start_with?("x-") }
        ext unless ext.nil? || ext.empty?
      end

      def normalize_headers(hdrs)
        return nil if hdrs.nil?
        return hdrs if hdrs.is_a?(Array)

        if hdrs.is_a?(Hash)
          return hdrs.map do |name, h|
            {
              name: name,
              schema: {
                "type" => h[:type] || h["type"] || "string",
                "description" => h[:desc] || h["description"]
              }.compact
            }
          end
        end
        nil
      end

      def headers_from_route
        hdrs = route.options.dig(:documentation, :headers) || route.settings.dig(:documentation, :headers)
        return [] unless hdrs.is_a?(Hash)

        hdrs.map do |name, h|
          {
            name: name,
            schema: {
              "type" => h[:type] || "string",
              "description" => h[:desc] || h[:description]
            }.compact
          }
        end
      end

      def build_schema(entity_class)
        schema_args = if entity_class
                        nullable = fetch_nullable_from_entity(entity_class)
                        { type: "object", canonical_name: entity_class.name, nullable: nullable }
                      else
                        { type: "string" }
                      end

        schema = GrapeOAS::ApiModel::Schema.new(**schema_args)
        if entity_class
          enrich_schema_with_entity_doc(schema, entity_class)
          schema = GrapeOAS::EntityIntrospector.new(entity_class).build_schema
        end
        schema
      end

      def fetch_nullable_from_entity(entity_class)
        doc = entity_class.respond_to?(:documentation) ? entity_class.documentation : {}
        doc[:nullable] || doc["nullable"] || false
      rescue StandardError
        false
      end

      def enrich_schema_with_entity_doc(schema, entity_class)
        return schema unless entity_class.respond_to?(:documentation)

        doc = entity_class.documentation
        schema.additional_properties = doc[:additional_properties] if doc.key?(:additional_properties)
        schema.unevaluated_properties = doc[:unevaluated_properties] if doc.key?(:unevaluated_properties)
        defs = doc[:defs] || doc[:$defs]
        schema.defs = defs if defs.is_a?(Hash)
        schema
      rescue StandardError
        schema
      end

      def build_media_type(mime_type:, schema:)
        GrapeOAS::ApiModel::MediaType.new(
          mime_type: mime_type,
          schema: schema,
        )
      end
    end
  end
end
