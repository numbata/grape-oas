# frozen_string_literal: true

# Start SimpleCov before loading any application code
require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end

SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  enable_coverage :branch

  add_group "Builders", "lib/grape_oas/api_model_builders"
  add_group "Parsers", "lib/grape_oas/api_model_builders/response_parsers"
  add_group "Introspectors", "lib/grape_oas/introspectors"
  add_group "Exporters", "lib/grape_oas/exporter"
  add_group "Models", "lib/grape_oas/api_model"

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter,
  ])
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
Bundler.setup :default, :test

require "minitest/autorun"
require "minitest/pride" if ENV["PRIDE"]

require "rack"
require "rack/test"
require "dry-schema" # Must be loaded before grape for contract support
require "dry/validation"
require "fileutils"
require "grape"
require "grape-entity"
require "grape-oas"

# Load support helpers (exclude *_test.rb to avoid circular requires)
Dir[File.expand_path("support/**/*.rb", __dir__)].reject { |f| f.end_with?("_test.rb") }.each { |f| require f }
