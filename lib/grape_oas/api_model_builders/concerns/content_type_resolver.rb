# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      # Shared module for resolving content types from routes, apps, and APIs.
      # Used by both Operation and Response builders to avoid code duplication.
      module ContentTypeResolver
        private

        def resolve_content_types
          default_format = route_default_format_from_route || default_format_from_app_or_api
          content_types = route_content_types_from_route
          content_types ||= content_types_from_app_or_api(default_format)

          mimes = []
          if content_types.is_a?(Hash)
            selected = content_types.select { |k, _| k.to_s.start_with?(default_format.to_s) } if default_format
            selected = content_types if selected.nil? || selected.empty?
            mimes = selected.values
          elsif content_types.respond_to?(:to_a) && !content_types.is_a?(String)
            mimes = content_types.to_a
          end

          mimes << mime_for_format(default_format) if mimes.empty? && default_format

          mimes = mimes.map { |m| normalize_mime(m) }.compact
          mimes.empty? ? [Constants::MimeTypes::JSON] : mimes.uniq
        end

        def mime_for_format(format)
          return if format.nil?
          return format if format.to_s.include?("/")

          return unless defined?(Grape::ContentTypes::CONTENT_TYPES)

          Grape::ContentTypes::CONTENT_TYPES[format.to_sym]
        end

        def normalize_mime(mime_or_format)
          return nil if mime_or_format.nil?
          return mime_or_format if mime_or_format.to_s.include?("/")

          mime_for_format(mime_or_format)
        end

        def route_content_types_from_route
          return route.settings[:content_types] || route.settings[:content_type] if route.respond_to?(:settings)

          route.options[:content_types] || route.options[:content_type]
        end

        def route_default_format_from_route
          return route.settings[:default_format] if route.respond_to?(:settings)

          route.options[:format]
        end

        # rubocop:disable Lint/RedundantSafeNavigation
        def default_format_from_app_or_api
          return api.default_format if api.respond_to?(:default_format)
          return app.default_format if app&.respond_to?(:default_format)

          api.settings[:default_format] if api.respond_to?(:settings) && api.settings[:default_format]
        rescue NoMethodError
          nil
        end

        def content_types_from_app_or_api(default_format)
          source = if api.respond_to?(:content_types)
                     api.content_types
                   elsif app&.respond_to?(:content_types)
                     app.content_types
                   elsif api.respond_to?(:settings)
                     api.settings[:content_types]
                   end
          # rubocop:enable Lint/RedundantSafeNavigation

          return nil unless source.is_a?(Hash)

          return source unless default_format

          filtered = source.select { |k, _| k.to_s.start_with?(default_format.to_s) }
          filtered.empty? ? source : filtered
        rescue NoMethodError
          nil
        end
      end
    end
  end
end
