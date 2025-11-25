# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "bundler", "~> 2.0"

gem "grape", path: ENV.fetch("GRAPE_PATH", "../grape")

gem "dry-schema"
gem "dry-validation"
gem "grape-entity"

group :development, :test do
  gem "debug"
  gem "rack"
  gem "rack-test"
  gem "rake"
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
end

gem "json_schemer", "~> 2.4", group: :test
