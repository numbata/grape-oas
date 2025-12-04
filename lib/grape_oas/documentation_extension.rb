# frozen_string_literal: true

module GrapeOAS
  module DocumentationExtension
    # Primary entry for grape-oas documentation
    def add_oas_documentation(**options)
      return if options.delete(:hide_documentation_path)

      # Prefer grape-oas namespaced options to avoid clashing with grape-swagger
      default_mount_path = options.delete(:oas_mount_path) ||
                           options.delete(:mount_path) ||
                           "/swagger_doc"
      default_format = options.delete(:oas_doc_version) ||
                       options.delete(:doc_version) ||
                       :oas3
      cache_control = options.delete(:cache_control)
      etag_value = options.delete(:etag)

      mount_paths = {
        default: default_mount_path,
        oas2: options.delete(:oas_mount_path_v2) || options.delete(:mount_path_v2),
        oas3: options.delete(:oas_mount_path_v3) || options.delete(:mount_path_v3)
      }.compact

      api = self

      mount_paths.each do |key, path|
        add_documentation_routes(path, key, default_format, cache_control, etag_value, options, api)
      end
    end

    def add_documentation_routes(path, key, default_format, cache_control, etag_value, options, api)
      # Main route without namespace filter
      add_route(path) do
        GrapeOAS::DocumentationExtension.generate_documentation(
          self, api, key, default_format, cache_control, etag_value, options, nil,
        )
      end

      # Route with namespace filter: /swagger_doc/:namespace
      # Supports nested namespaces via *namespace (catches slashes)
      add_route("#{path}/*namespace") do
        namespace_filter = params[:namespace]&.sub(/\.json$/, "")
        GrapeOAS::DocumentationExtension.generate_documentation(
          self, api, key, default_format, cache_control, etag_value, options, namespace_filter,
        )
      end
    end

    def self.generate_documentation(endpoint, api, key, default_format, cache_control, etag_value, options, namespace_filter)
      schema_type = if key == :oas2
                      :oas2
                    elsif key == :oas3
                      :oas3
                    else
                      parse_schema_type(endpoint.params[:oas]) || default_format
                    end

      endpoint.header("Cache-Control", cache_control) if cache_control
      endpoint.header("ETag", etag_value) if etag_value

      # Resolve runtime options (like grape-swagger's OptionalObject)
      runtime_options = options.dup
      runtime_options[:host] = resolve_option(
        runtime_options[:host], endpoint.request, :host_with_port,
      )
      runtime_options[:base_path] = resolve_option(
        runtime_options[:base_path], endpoint.request, :script_name,
      )
      runtime_options[:namespace] = namespace_filter if namespace_filter

      GrapeOAS.generate(app: api, schema_type: schema_type, **runtime_options)
    end

    # Compatibility shim for apps calling grape-swagger's add_swagger_documentation.
    #
    # If grape-swagger is loaded we defer to its implementation to keep legacy
    # behaviour untouched. Only when grape-swagger is absent do we fall back to
    # grape-oas.
    def add_swagger_documentation(**options)
      return super if defined?(::GrapeSwagger)

      options = options.dup
      options[:oas_doc_version] ||= :oas2
      options[:oas_mount_path] ||= options[:mount_path] || "/swagger_doc.json"
      add_oas_documentation(**options)
    end

    private

    # Minimal route mounting helper
    def add_route(path, &block)
      api_class = self
      namespace do
        get(path) { instance_exec(api_class, &block) }
      end
    end

    def parse_schema_type(value)
      case value&.to_s
      when "2", "oas2", "swagger"
        :oas2
      when "3.1", "31", "oas31", "oas3_1", "openapi31"
        :oas31
      when "3", "oas3", "openapi", "oas30", "oas3_0", "openapi30"
        :oas3
      end
    end
    module_function :parse_schema_type

    # Resolve option value at request time (like grape-swagger's OptionalObject)
    # Supports: static values, Proc/lambda (with optional request arg), or fallback to request method
    def resolve_option(value, request, default_method)
      if value.is_a?(Proc)
        value.arity.zero? ? value.call : value.call(request)
      elsif value
        value
      elsif request
        request.send(default_method)
      end
    end
    module_function :resolve_option
  end
end
