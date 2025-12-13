# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "bundler", "~> 2.0"

gem "grape", case ENV.fetch("GRAPE_VERSION", nil)
             when "HEAD"
               { git: "https://github.com/ruby-grape/grape" }
             when nil
               ENV.key?("GRAPE_PATH") ? { path: ENV.fetch("GRAPE_PATH") } : ">= 3.0"
             else
               ENV.fetch("GRAPE_VERSION")
             end

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

group :test do
  gem "benchmark-ips"
  gem "json_schemer", "~> 2.4"
  gem "memory_profiler"
  gem "simplecov", require: false
  gem "simplecov-lcov", require: false
  gem "stackprof"
end
