# frozen_string_literal: true

require "test_helper"
require_relative "oas_validator"

class OASValidatorTest < Minitest::Test
  def test_valid_oas31_minimal_passes
    doc = {
      "openapi" => "3.1.0",
      "$schema" => "https://spec.openapis.org/oas/3.1/draft/2021-05",
      "info" => { "title" => "t", "version" => "1" },
      "components" => {},
      "paths" => {}
    }

    assert OASValidator.validate!(doc)
  end

  def test_invalid_oas31_missing_required_fields_fails
    doc = {
      "openapi" => "3.1.0",
      "info" => { "title" => "t" }, # version missing
      "components" => {},
      "paths" => {}
    }

    assert_raises(OASValidator::ValidationError) { OASValidator.validate!(doc) }
  end
end
