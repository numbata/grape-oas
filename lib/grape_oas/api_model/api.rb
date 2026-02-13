# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Represents the root API object in the DTO model for OpenAPI v2/v3.
    # Contains metadata, paths, servers, tags, and components.
    # Used as the entry point for building OpenAPIv2 and OpenAPIv3 documents.
    #
    # @see https://swagger.io/specification/
    # @see GrapeOAS::ApiModel::Path
    class API < Node
      attr_accessor :title, :version, :paths, :servers, :tag_defs, :components,
                    :host, :base_path, :schemes, :security_definitions, :security,
                    :registered_schemas, :suppress_default_error_response, :nullable_strategy

      def initialize(title:, version:)
        super()
        @title      = title
        @version    = version
        @paths      = Set.new
        @servers    = []
        @tag_defs   = Set.new
        @components = {}
        @host       = nil
        @base_path  = nil
        @schemes    = []
        @security_definitions = {}
        @security = []
        @registered_schemas = []
        @suppress_default_error_response = false
        @nullable_strategy = nil
      end

      def add_path(path)
        @paths << path
      end

      def add_tags(*tags)
        @tag_defs.merge(tags)
      end
    end
  end
end
