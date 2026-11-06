# frozen_string_literal: true

require "test_helper"
require "ripper"

class SorbetSignatureTest < Minitest::Test
  SIGNATURE_PATH = File.expand_path("../../rbi/grape_oas.rbi", __dir__)

  def test_signature_is_valid_ruby
    refute_nil Ripper.sexp(File.read(SIGNATURE_PATH))
  end

  def test_signature_is_packaged
    gemspec = Gem::Specification.load(File.expand_path("../../grape-oas.gemspec", __dir__))

    assert_includes gemspec.files, "rbi/grape_oas.rbi"
  end
end
