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
  #     version: "1.0.0"
  #   )
  #
  def generate(app:, schema_type: :oas3, **options)
    api_model = GrapeOAS::ApiModelBuilder.new(options)
    api_model.add_app(app)

    GrapeOAS::Exporter.for(schema_type)
                      .new(api_model: api_model.api)
                      .generate
  end
  module_function :generate
end

Grape::API::Instance.extend(GrapeOAS::DocumentationExtension)
