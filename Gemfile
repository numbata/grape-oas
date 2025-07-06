# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "bundler", "~> 2.0"

gem "grape", case version = ENV.fetch("GRAPE_VERSION", "< 3.0")
             when "HEAD"
               { git: "https://github.com/ruby-grape/grape" }
             else
               version
             end

group :development, :test do
  gem "debug"
  gem "rack"
  gem "rack-test"
  gem "rake"
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
end
