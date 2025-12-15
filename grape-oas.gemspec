# frozen_string_literal: true

require_relative "lib/grape_oas/version"

Gem::Specification.new do |spec|
  spec.name = "grape-oas"
  spec.version = GrapeOAS::VERSION
  spec.authors = ["Andrei Subbota"]
  spec.email = ["subbota@gmail.com"]

  spec.summary = "OpenAPI (Swagger) v2 and v3 documentation for Grape APIs"
  spec.description = "A Grape extension that provides OpenAPI (Swagger) v2 and v3 documentation support"
  spec.homepage = "https://github.com/numbata/grape-oas"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "github_repo" => "https://github.com/numbata/grape-oas",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "#{spec.homepage}#readme",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "*.md", "LICENSE.txt", "grape-oas.gemspec"]

  spec.add_dependency "grape", ">= 3.0"
  spec.add_dependency "zeitwerk"
end
