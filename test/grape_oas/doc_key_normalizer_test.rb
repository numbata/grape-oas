# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  class DocKeyNormalizerTest < Minitest::Test
    def test_symbol_keys_stay_as_symbols
      input = { type: String, desc: "hello", required: true }
      result = DocKeyNormalizer.normalize(input)

      assert_equal %i[type desc required], result.keys
    end

    def test_string_keys_become_symbols
      input = { "type" => String, "desc" => "hello" }
      result = DocKeyNormalizer.normalize(input)

      assert_equal %i[type desc], result.keys
    end

    def test_x_extension_string_keys_stay_as_strings
      input = { "x-internal" => true, "x-tags" => %w[a b] }
      result = DocKeyNormalizer.normalize(input)

      assert_includes result.keys, "x-internal"
      assert_includes result.keys, "x-tags"
    end

    def test_x_extension_symbol_keys_become_strings
      input = { "x-source": "branch-a" }
      result = DocKeyNormalizer.normalize(input)

      assert_includes result.keys, "x-source"
      refute_includes result.keys, :"x-source"
    end

    def test_mixed_keys_normalized_correctly
      input = { "type" => String, "x-tag" => "ext", desc: "desc" }
      result = DocKeyNormalizer.normalize(input)

      assert_includes result.keys, :type
      assert_includes result.keys, :desc
      assert_includes result.keys, "x-tag"
    end

    def test_empty_hash_returns_empty_hash
      result = DocKeyNormalizer.normalize({})

      assert_empty(result)
    end

    def test_values_are_preserved
      input = { type: Integer, "x-meta" => { "key" => "val" } }
      result = DocKeyNormalizer.normalize(input)

      assert_equal Integer, result[:type]
      assert_equal({ "key" => "val" }, result["x-meta"])
    end
  end
end
