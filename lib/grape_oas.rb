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

module GrapeOAS
  # Provides the version of the GrapeOAS gem
  # @return [String] the version of the GrapeOAS gem
  def version
    OAS::VERSION
  end
  module_function :version

  # Generates an OpenAPI schema from a Grape application
  # @param app [Grape::API] the Grape application to generate the schema from
  # @param schema_type [Symbol] the type of OpenAPI schema to generate, either :oas3 or :oas2
  # @return [Hash] the generated OpenAPI schema
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
