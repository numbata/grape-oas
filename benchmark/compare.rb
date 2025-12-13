# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken

# benchmark/compare.rb
# Compares two JSON benchmark results and reports regressions
#
# Usage:
#   ruby benchmark/compare.rb baseline.json current.json
#   ruby benchmark/compare.rb baseline.json current.json --ci
#
# Exit codes:
#   0 - No significant regression
#   1 - Regression detected (>10% slower)

require "json"

class BenchmarkComparer
  REGRESSION_THRESHOLD = -10.0 # Slower by this % = regression
  IMPROVEMENT_THRESHOLD = 10.0 # Faster by this % = improvement

  def initialize(baseline_path, current_path, ci_mode: false)
    @baseline = JSON.parse(File.read(baseline_path))
    @current = JSON.parse(File.read(current_path))
    @ci_mode = ci_mode
    @regressions = []
    @improvements = []
  end

  # rubocop:disable Naming/PredicateMethod
  def run(silent: false)
    if silent
      analyze_results
    else
      puts header unless @ci_mode
      analyze_results
      puts comparison_table
      puts summary
    end
    @regressions.any?
  end
  # rubocop:enable Naming/PredicateMethod

  def markdown_report
    <<~MARKDOWN
      ## Benchmark Comparison

      #{status_badge}

      #{comparison_table_markdown}

      #{details_section}
    MARKDOWN
  end

  private

  def header
    <<~HEADER
      Benchmark Comparison
      ====================
      Baseline: #{@baseline["timestamp"]} (Ruby #{@baseline["ruby_version"]})
      Current:  #{@current["timestamp"]} (Ruby #{@current["ruby_version"]})

    HEADER
  end

  def analyze_results
    baseline_results = @baseline["results"]
    current_results = @current["results"]

    all_benchmarks = (baseline_results.keys + current_results.keys).uniq.sort

    all_benchmarks.each do |name|
      baseline_ips = baseline_results.dig(name, "iterations_per_second")
      current_ips = current_results.dig(name, "iterations_per_second")

      next unless baseline_ips && current_ips

      change_pct = ((current_ips - baseline_ips) / baseline_ips * 100).round(2)

      if change_pct < REGRESSION_THRESHOLD
        @regressions << { name: name, change: change_pct, baseline: baseline_ips, current: current_ips }
      elsif change_pct > IMPROVEMENT_THRESHOLD
        @improvements << { name: name, change: change_pct, baseline: baseline_ips, current: current_ips }
      end
    end
  end

  def comparison_table
    lines = []
    lines << "Benchmark                     Baseline      Current     Change  Status"
    lines << ("-" * 75)

    baseline_results = @baseline["results"]
    current_results = @current["results"]

    all_benchmarks = (baseline_results.keys + current_results.keys).uniq.sort

    all_benchmarks.each do |name|
      baseline_ips = baseline_results.dig(name, "iterations_per_second")
      current_ips = current_results.dig(name, "iterations_per_second")

      if baseline_ips && current_ips
        change_pct = ((current_ips - baseline_ips) / baseline_ips * 100).round(2)
        status = status_icon(change_pct)

        lines << format(
          "%-25s %10.2f/s %10.2f/s %+9.1f%%  %s",
          truncate(name, 25),
          baseline_ips,
          current_ips,
          change_pct,
          status,
        )
      elsif baseline_ips
        lines << format("%-25s %10.2f/s %12s %10s  %s", truncate(name, 25), baseline_ips, "N/A", "-", "removed")
      else
        lines << format("%-25s %12s %10.2f/s %10s  %s", truncate(name, 25), "N/A", current_ips, "-", "new")
      end
    end

    lines.join("\n")
  end

  def comparison_table_markdown
    lines = []
    lines << "| Benchmark | Baseline | Current | Change | Status |"
    lines << "|-----------|----------|---------|--------|--------|"

    baseline_results = @baseline["results"]
    current_results = @current["results"]

    all_benchmarks = (baseline_results.keys + current_results.keys).uniq.sort

    all_benchmarks.each do |name|
      baseline_ips = baseline_results.dig(name, "iterations_per_second")
      current_ips = current_results.dig(name, "iterations_per_second")

      next unless baseline_ips && current_ips

      change_pct = ((current_ips - baseline_ips) / baseline_ips * 100).round(2)
      status = status_emoji(change_pct)

      lines << format(
        "| %s | %.2f/s | %.2f/s | %+.1f%% | %s |",
        name,
        baseline_ips,
        current_ips,
        change_pct,
        status,
      )
    end

    lines.join("\n")
  end

  def status_icon(change_pct)
    if change_pct < REGRESSION_THRESHOLD
      "REGRESSION"
    elsif change_pct > IMPROVEMENT_THRESHOLD
      "improved"
    else
      "stable"
    end
  end

  def status_emoji(change_pct)
    if change_pct < REGRESSION_THRESHOLD
      "REGRESSION"
    elsif change_pct > IMPROVEMENT_THRESHOLD
      "Improved"
    else
      "Stable"
    end
  end

  def status_badge
    if @regressions.any?
      "**Status: REGRESSION DETECTED**"
    else
      "**Status: No significant regression**"
    end
  end

  def summary
    lines = []
    lines << ""
    lines << "Summary"
    lines << ("-" * 40)

    if @regressions.any?
      lines << "REGRESSIONS (#{@regressions.size}):"
      @regressions.each do |r|
        lines << "  - #{r[:name]}: #{r[:change]}% slower"
      end
    end

    if @improvements.any?
      lines << "Improvements (#{@improvements.size}):"
      @improvements.each do |i|
        lines << "  + #{i[:name]}: +#{i[:change]}% faster"
      end
    end

    lines << "All benchmarks within normal variance (+-10%)" if @regressions.empty? && @improvements.empty?

    lines << ""
    lines << "Result: #{@regressions.any? ? "REGRESSION DETECTED" : "No significant regression"}"

    lines.join("\n")
  end

  def details_section
    <<~DETAILS
      <details>
      <summary>About these benchmarks</summary>

      - Measurements are in iterations per second (higher is better)
      - Changes > 10% are flagged as potential regressions
      - Results may vary slightly between runs

      **Baseline:** #{@baseline["timestamp"]}
      **Current:** #{@current["timestamp"]}
      </details>
    DETAILS
  end

  def truncate(str, max)
    str.length > max ? "#{str[0, max - 2]}.." : str
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.length < 2 || ARGV.include?("--help") || ARGV.include?("-h")
    puts "Usage: ruby benchmark/compare.rb <baseline.json> <current.json> [--ci]"
    puts
    puts "Options:"
    puts "  --ci       CI mode (affects exit code)"
    puts "  --markdown Output markdown report"
    exit ARGV.include?("--help") ? 0 : 1
  end

  baseline_path = ARGV[0]
  current_path = ARGV[1]
  ci_mode = ARGV.include?("--ci")
  markdown = ARGV.include?("--markdown")

  [baseline_path, current_path].each do |path|
    unless File.exist?(path)
      warn "Error: File not found: #{path}"
      exit 1
    end
  end

  comparer = BenchmarkComparer.new(baseline_path, current_path, ci_mode: ci_mode)

  if markdown
    has_regression = comparer.run(silent: true)
    puts comparer.markdown_report
  else
    has_regression = comparer.run
  end

  exit(has_regression ? 1 : 0)
end

# rubocop:enable Style/FormatStringToken
