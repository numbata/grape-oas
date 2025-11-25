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

      @apis = []
    end

    def add_app(app)
      GrapeOAS::ApiModelBuilders::Path
        .new(api: @api, routes: app.routes)
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
  end
end
