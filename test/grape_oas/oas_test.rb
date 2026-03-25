# frozen_string_literal: true

require "test_helper"

class GrapeOASTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::GrapeOAS::VERSION
  end

  def test_module_defined
    assert defined?(GrapeOAS)
  end

  def test_logger_returns_default_logger
    GrapeOAS.instance_variable_set(:@logger, nil)

    assert_respond_to GrapeOAS.logger, :warn
  ensure
    GrapeOAS.instance_variable_set(:@logger, nil)
  end

  def test_default_logger_formats_with_grape_oas_prefix
    GrapeOAS.instance_variable_set(:@logger, nil)
    output = capture_grape_oas_log { GrapeOAS.logger.warn("test message") }

    assert_equal "[grape-oas] test message\n", output
  ensure
    GrapeOAS.instance_variable_set(:@logger, nil)
  end

  def test_logger_setter_accepts_warn_compatible_object
    custom = Object.new
    custom.define_singleton_method(:warn) { |_msg| nil }
    GrapeOAS.logger = custom

    assert_same custom, GrapeOAS.logger
  ensure
    GrapeOAS.instance_variable_set(:@logger, nil)
  end

  def test_logger_setter_accepts_nil_to_reset_to_default
    custom = Object.new
    custom.define_singleton_method(:warn) { |_msg| nil }
    GrapeOAS.logger = custom
    GrapeOAS.logger = nil

    assert_respond_to GrapeOAS.logger, :warn
    refute_same custom, GrapeOAS.logger
  ensure
    GrapeOAS.instance_variable_set(:@logger, nil)
  end

  def test_logger_setter_raises_for_object_without_warn
    assert_raises(ArgumentError) { GrapeOAS.logger = Object.new }
  end

  def test_logger_setter_raises_with_informative_message
    error = assert_raises(ArgumentError) { GrapeOAS.logger = 42 }
    assert_match(/must respond to :warn/, error.message)
    assert_match(/Integer/, error.message)
  end

  def test_logger_routes_warnings_through_configurable_logger
    messages = []
    custom = Object.new
    custom.define_singleton_method(:warn) { |msg| messages << msg }
    GrapeOAS.logger = custom
    GrapeOAS.logger.warn("something went wrong")

    assert_equal ["something went wrong"], messages
  ensure
    GrapeOAS.instance_variable_set(:@logger, nil)
  end
end
