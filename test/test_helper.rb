# frozen_string_literal: true

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
