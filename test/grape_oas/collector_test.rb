# frozen_string_literal: true

require "test_helper"

class CollectorTest < Minitest::Test
  def test_placeholder
    assert_kind_of Module, GrapeOAS
  end
end
