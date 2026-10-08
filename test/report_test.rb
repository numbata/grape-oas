# frozen_string_literal: true

require "minitest/autorun"
require_relative "../site/report"

class ReportTest < Minitest::Test
  def test_median_and_change_have_correct_direction
    assert_equal 3, BenchmarkReport.median([9, 1, 3])
    assert_equal 4, BenchmarkReport.median([9, 3, 5, 1])
    assert_equal(-25, BenchmarkReport.change(3, 4))
    assert_nil BenchmarkReport.change(3, 0)
  end

  def test_failed_cases_never_produce_comparisons
    targets = [target("v1", [4, 4]), target("v2", nil), target("main", [2, 2])]
    rows = BenchmarkReport.rows({ "targets" => targets }, 100, "oas3")

    assert_equal "Failed generation", rows[1][:error]
    assert_nil rows[1][:median]
    assert_nil rows[2][:previous]
    assert_equal(-50, rows[2][:baseline])
  end

  def test_failed_baseline_never_produces_a_baseline_comparison
    rows = BenchmarkReport.rows({ "targets" => [target("v1", nil), target("main", [2, 2])] }, 100, "oas3")

    assert_nil rows.last[:baseline]
  end

  private

  def target(label, samples)
    benchmark_case = { "routes" => 100, "format" => "oas3" }
    samples ? benchmark_case["samples_ms"] = samples : benchmark_case["error"] = "Failed generation"
    { "label" => label, "sha" => "a" * 40, "cases" => [benchmark_case] }
  end
end
