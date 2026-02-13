# frozen_string_literal: true

module GrapeOAS
  class ApiModelBuilder
    attr_reader :api

    def initialize(options = {})
      @api = GrapeOAS::ApiModel::API.new(
        title: options.dig(:info, :title) || options[:title] || "Grape API",
        version: options.dig(:info, :version) || options[:version] || "1",
      )

      @api.host = options[:host]
      @api.base_path = normalize_base_path(options[:base_path])
      @api.schemes = Array(options[:schemes]).compact
      @api.security_definitions = options[:security_definitions] || {}
      @api.security = options[:security] || []
      @api.tag_defs.merge(Array(options[:tags])) if options[:tags]
      @api.servers = build_servers(options)
      @api.registered_schemas = build_registered_schemas(options[:models])
      @api.suppress_default_error_response = options[:suppress_default_error_response] || false
      @api.nullable_strategy = options[:nullable_strategy]

      @namespace_filter = options[:namespace]
      @apis = []
    end

    def add_app(app)
      GrapeOAS::ApiModelBuilders::Path
        .new(api: @api, routes: app.routes, app: app, namespace_filter: @namespace_filter)
        .build
    end

    private

    def normalize_base_path(path)
      return nil unless path

      path.start_with?("/") ? path : "/#{path}"
    end

    def build_servers(options)
      return options[:servers] if options[:servers]
      return [] unless options[:host]

      scheme = Array(options[:schemes]).compact.first || "https"
      url = "#{scheme}://#{options[:host]}#{normalize_base_path(options[:base_path])}"
      [{ "url" => url }]
    end

    # Build schemas from pre-registered models (entities/contracts)
    # This allows adding models to definitions even if not referenced by endpoints
    def build_registered_schemas(models)
      return [] unless models

      Array(models).map do |model|
        model = model.constantize if model.is_a?(String)
        GrapeOAS.introspectors.build_schema(model, stack: [], registry: {})
      rescue StandardError
        nil
      end.compact
    end
  end
end
