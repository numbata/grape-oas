# frozen_string_literal: true

require "grape"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "api" => "API",
  "grape-oas" => "GrapeOAS",
  "grape_oas" => "GrapeOAS",
  "oas2" => "OAS2",
  "oas2_schema" => "OAS2Schema",
  "oas3" => "OAS3",
  "oas3_schema" => "OAS3Schema",
  "oas30" => "OAS30",
  "oas30_schema" => "OAS30Schema",
  "oas31" => "OAS31",
  "oas31_schema" => "OAS31Schema",
)
loader.ignore("#{__dir__}/grape-oas.rb")
loader.setup

# GrapeOAS generates OpenAPI specifications from Grape APIs.
#
# @example Basic usage
#   schema = GrapeOAS.generate(app: MyAPI)
#   puts JSON.pretty_generate(schema)
#
# @example Generate OpenAPI 2.0 (Swagger)
#   schema = GrapeOAS.generate(app: MyAPI, schema_type: :oas2)
#
# @example Generate OpenAPI 3.1
#   schema = GrapeOAS.generate(app: MyAPI, schema_type: :oas31)
#
module GrapeOAS
  # Returns the version of the GrapeOAS gem.
  #
  # @return [String] the semantic version string
  def version
    OAS::VERSION
  end
  module_function :version

  # Returns the global introspector registry.
  #
  # The registry manages introspectors that build schemas from various sources
  # (e.g., Grape::Entity, Dry contracts). Third-party gems can register custom
  # introspectors to support new schema definition formats.
  #
  # @return [Introspectors::Registry] the global introspector registry
  #
  # @example Registering a custom introspector
  #   GrapeOAS.introspectors.register(MyCustomIntrospector)
  #
  # @example Inserting before an existing introspector
  #   GrapeOAS.introspectors.register(
  #     HighPriorityIntrospector,
  #     before: GrapeOAS::Introspectors::EntityIntrospector
  #   )
  #
  def introspectors
    @introspectors ||= begin
      registry = Introspectors::Registry.new
      # Register built-in introspectors in order of precedence
      registry.register(Introspectors::EntityIntrospector)
      registry.register(Introspectors::DryIntrospector)
      registry
    end
  end
  module_function :introspectors

  # Returns the global exporter registry.
  #
  # The registry manages exporters that generate OpenAPI specifications
  # in different versions (OAS 2.0, 3.0, 3.1). Third-party gems can register
  # custom exporters for new output formats.
  #
  # @return [Exporter::Registry] the global exporter registry
  #
  # @example Registering a custom exporter
  #   GrapeOAS.exporters.register(:custom, MyCustomExporter)
  #
  # @example Using a custom exporter
  #   schema = GrapeOAS.generate(app: MyAPI, schema_type: :custom)
  #
  def exporters
    @exporters ||= begin
      registry = Exporter::Registry.new
      # Register built-in exporters
      registry.register(Exporter::OAS2Schema, as: :oas2)
      registry.register(Exporter::OAS30Schema, as: %i[oas3 oas30])
      registry.register(Exporter::OAS31Schema, as: :oas31)
      registry
    end
  end
  module_function :exporters

  # Returns the global type resolver registry.
  #
  # The registry manages type resolvers that convert Grape's stringified types
  # back to OpenAPI schemas. Grape stores parameter types as strings for memory
  # optimization, but TypeResolvers can resolve them back to actual classes
  # and extract rich metadata (e.g., Dry::Types format, constraints).
  #
  # @return [TypeResolvers::Registry] the global type resolver registry
  #
  # @example Registering a custom type resolver
  #   GrapeOAS.type_resolvers.register(MyCustomTypeResolver)
  #
  # @example Inserting before an existing resolver
  #   GrapeOAS.type_resolvers.register(
  #     HighPriorityResolver,
  #     before: GrapeOAS::TypeResolvers::ArrayResolver
  #   )
  #
  def type_resolvers
    @type_resolvers ||= begin
      registry = TypeResolvers::Registry.new
      # Register built-in resolvers in order of precedence
      # ArrayResolver handles "[Type]" patterns first
      registry.register(TypeResolvers::ArrayResolver)
      # DryTypeResolver handles Dry::Types (standalone, not arrays)
      registry.register(TypeResolvers::DryTypeResolver)
      # PrimitiveResolver is the fallback for basic types
      registry.register(TypeResolvers::PrimitiveResolver)
      registry
    end
  end
  module_function :type_resolvers

  # Generates an OpenAPI specification from a Grape API application.
  #
  # Introspects the Grape API routes, parameters, entities, and contracts
  # to produce a complete OpenAPI specification document.
  #
  # @param app [Class<Grape::API>] The Grape API class to document
  # @param schema_type [Symbol] The OpenAPI version to generate
  #   - `:oas2` - OpenAPI 2.0 (Swagger)
  #   - `:oas3` - OpenAPI 3.0 (default)
  #   - `:oas31` - OpenAPI 3.1
  # @param options [Hash] Additional options passed to the API model builder
  # @option options [String] :title API title for the info section
  # @option options [String] :version API version string
  # @option options [Array<String>] :servers Server URLs (OAS3 only)
  # @option options [Hash] :license License information
  # @option options [Hash] :security_definitions Security scheme definitions
  # @option options [String] :namespace Filter routes to only include paths
  #   starting with this namespace (e.g., "users" includes /users and /users/{id})
  #
  # @return [Hash] The OpenAPI specification as a Hash (JSON-serializable)
  #
  # @example Basic generation
  #   schema = GrapeOAS.generate(app: MyAPI)
  #
  # @example With custom metadata
  #   schema = GrapeOAS.generate(
  #     app: MyAPI,
  #     schema_type: :oas3,
  #     title: "My API",
  #     version: "1.1.0"
  #   )
  #
  # @example Filter by namespace
  #   schema = GrapeOAS.generate(app: MyAPI, namespace: "users")
  #   # Only includes paths like /users, /users/{id}, etc.
  #
  def generate(app:, schema_type: :oas3, **options)
    if options[:nullable_strategy].nil? && options.key?(:nullable_keyword) && %i[oas3 oas30].include?(schema_type)
      options[:nullable_strategy] = if options[:nullable_keyword] == false
                                      Constants::NullableStrategy::TYPE_ARRAY
                                    else
                                      Constants::NullableStrategy::KEYWORD
                                    end
    end

    api_model = GrapeOAS::ApiModelBuilder.new(options)
    api_model.add_app(app)

    GrapeOAS::Exporter.for(schema_type)
                      .new(api_model: api_model.api)
                      .generate
  end
  module_function :generate
end

Grape::API::Instance.extend(GrapeOAS::DocumentationExtension)
