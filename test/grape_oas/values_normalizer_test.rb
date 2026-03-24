# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class ValuesNormalizerTest < Minitest::Test
    def test_returns_nil_for_nil_input
      assert_nil ValuesNormalizer.normalize(nil)
    end

    def test_passes_through_array
      assert_equal %w[a b c], ValuesNormalizer.normalize(%w[a b c])
    end

    def test_passes_through_range
      assert_equal 1..10, ValuesNormalizer.normalize(1..10)
    end

    def test_converts_set_to_array
      result = ValuesNormalizer.normalize(Set.new(%w[x y]))

      assert_instance_of Array, result
      assert_equal 2, result.size
    end

    def test_unwraps_hash_with_value_key
      assert_equal %w[a b], ValuesNormalizer.normalize({ value: %w[a b], message: "pick one" })
    end

    def test_returns_nil_for_hash_with_nil_value
      assert_nil ValuesNormalizer.normalize({ value: nil, message: "pick one" })
    end

    def test_evaluates_arity_zero_proc
      assert_equal %w[open closed], ValuesNormalizer.normalize(proc { %w[open closed] })
    end

    def test_evaluates_arity_zero_lambda
      assert_equal [1, 2, 3], ValuesNormalizer.normalize(-> { [1, 2, 3] })
    end

    def test_skips_validator_proc_with_arity_greater_than_zero
      assert_nil ValuesNormalizer.normalize(->(v) { v.match?(/^[A-Z]+$/) })
    end

    def test_skips_callable_without_arity
      callable = Class.new do
        def self.call(value) # rubocop:disable Naming/PredicateMethod
          !value.to_s.empty?
        end
      end

      assert_nil ValuesNormalizer.normalize(callable)
    end

    def test_skips_optional_arg_validator_proc
      # proc { |v = nil| ... } reports arity 0 but returns non-enum
      assert_nil ValuesNormalizer.normalize(proc { |v = nil| v.to_s.length < 10 })
    end

    def test_rescues_raising_proc
      _, stderr = capture_io do
        @result = ValuesNormalizer.normalize(proc { raise ArgumentError, "boom" })
      end

      assert_nil @result
      assert_match(/Proc evaluation failed/, stderr)
      assert_match(/ArgumentError/, stderr)
    end

    def test_includes_context_in_warning
      _, stderr = capture_io do
        ValuesNormalizer.normalize(proc { raise "oops" }, context: "field 'status'")
      end

      assert_match(/field 'status'/, stderr)
    end

    def test_passes_through_false_only_array
      assert_equal [false], ValuesNormalizer.normalize([false])
    end

    def test_returns_nil_for_empty_array
      assert_nil ValuesNormalizer.normalize([])
    end

    def test_unwraps_hash_wrapped_proc
      assert_equal %w[x y z], ValuesNormalizer.normalize({ value: proc { %w[x y z] }, message: "pick one" })
    end

    def test_returns_nil_for_except_hash_format
      # Grape's { except: [...] } exclusion format is not a value enum — treat as nil
      assert_nil ValuesNormalizer.normalize({ except: [1, 2, 3] })
    end

    def test_proc_returning_range
      result = ValuesNormalizer.normalize(proc { "a".."z" })

      assert_equal "a".."z", result
    end

    def test_proc_returning_set_converts_to_array
      result = ValuesNormalizer.normalize(proc { Set.new([1, 2]) })

      assert_instance_of Array, result
      assert_equal 2, result.size
    end

    def test_returns_nil_for_proc_returning_scalar
      assert_nil ValuesNormalizer.normalize(proc { 42 })
      assert_nil ValuesNormalizer.normalize(proc { "hello" })
    end
  end
end
