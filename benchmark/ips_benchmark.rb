# frozen_string_literal: true

# benchmark/ips_benchmark.rb
# Measures iterations per second for OAS generation
#
# Usage:
#   ruby benchmark/ips_benchmark.rb              # Human-readable output
#   ruby benchmark/ips_benchmark.rb --json       # JSON output for CI/comparison
#   ruby benchmark/ips_benchmark.rb --quick      # Quick run (shorter time)
#   ruby benchmark/ips_benchmark.rb --scenarios  # Run detailed scenario benchmarks

require_relative "support/test_api"
require "benchmark/ips"
require "json"
require "time"

class IPSBenchmark
  BENCHMARKS = {
    "oas3_complex" => {
      description: "OAS 3.0 generation for complex API (~25 endpoints)",
      block: -> { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3) }
    },
    "oas2_complex" => {
      description: "OAS 2.0 (Swagger) generation for complex API",
      block: -> { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas2) }
    },
    "oas31_complex" => {
      description: "OAS 3.1 generation for complex API",
      block: -> { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas31) }
    },
    "oas3_simple" => {
      description: "OAS 3.0 generation for simple API (~3 endpoints)",
      block: -> { GrapeOAS.generate(app: SimpleAPI, schema_type: :oas3) }
    }
  }.freeze

  def initialize(json_output: false, quick: false)
    @json_output = json_output
    @quick = quick
    @time = quick ? 1 : 3
    @warmup = quick ? 0.5 : 1
  end

  def run
    if @json_output
      run_json
    else
      run_human_readable
    end
  end

  def run_scenarios
    run_format_comparison
    run_complexity_comparison
    run_pipeline_breakdown
  end

  private

  def run_json
    results = {}

    BENCHMARKS.each do |name, config|
      # Warmup
      3.times { config[:block].call }

      # Measure
      iterations = 0
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end_time = start_time + (@quick ? 1.0 : 2.0)

      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < end_time
        config[:block].call
        iterations += 1
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      ips = iterations / elapsed

      results[name] = {
        iterations_per_second: ips.round(2),
        iterations: iterations,
        elapsed_seconds: elapsed.round(4),
        description: config[:description]
      }
    end

    output = {
      timestamp: Time.now.iso8601,
      ruby_version: RUBY_VERSION,
      grape_oas_version: GrapeOAS::VERSION,
      quick_mode: @quick,
      results: results
    }

    puts JSON.pretty_generate(output)
  end

  def run_human_readable
    puts "=" * 70
    puts "grape-oas IPS Benchmark"
    puts "=" * 70
    puts "Ruby #{RUBY_VERSION} | grape-oas #{GrapeOAS::VERSION}"
    puts "API endpoints: BenchmarkAPI=#{BenchmarkAPI.routes.size}, SimpleAPI=#{SimpleAPI.routes.size}"
    puts "Mode: #{@quick ? "quick" : "full"} (time=#{@time}s, warmup=#{@warmup}s)"
    puts "=" * 70
    puts

    Benchmark.ips do |x|
      x.config(time: @time, warmup: @warmup)

      BENCHMARKS.each do |name, config|
        x.report(name, &config[:block])
      end

      x.compare!
    end
  end

  def run_format_comparison
    puts "\n#{"=" * 70}"
    puts "Scenario: OAS Format Comparison"
    puts "=" * 70

    Benchmark.ips do |x|
      x.config(time: @time, warmup: @warmup)

      x.report("OAS 2.0 (Swagger)") { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas2) }
      x.report("OAS 3.0") { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3) }
      x.report("OAS 3.1") { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas31) }

      x.compare!
    end
  end

  def run_complexity_comparison
    puts "\n#{"=" * 70}"
    puts "Scenario: API Complexity Impact"
    puts "=" * 70

    Benchmark.ips do |x|
      x.config(time: @time, warmup: @warmup)

      x.report("Simple API (~3 endpoints)") { GrapeOAS.generate(app: SimpleAPI, schema_type: :oas3) }
      x.report("Complex API (~25 endpoints)") { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3) }

      x.compare!
    end
  end

  def run_pipeline_breakdown
    puts "\n#{"=" * 70}"
    puts "Scenario: Pipeline Stage Breakdown"
    puts "=" * 70

    # Check if introspection/export APIs are available
    unless GrapeOAS.respond_to?(:introspect) || defined?(GrapeOAS::Introspectors)
      puts "Skipping: Pipeline breakdown requires internal API access"
      return
    end

    Benchmark.ips do |x|
      x.config(time: @time, warmup: @warmup)

      x.report("Full pipeline") { GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3) }

      x.compare!
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  json_output = ARGV.include?("--json")
  quick = ARGV.include?("--quick")
  scenarios = ARGV.include?("--scenarios")

  if ARGV.include?("--help") || ARGV.include?("-h")
    puts "Usage: ruby benchmark/ips_benchmark.rb [OPTIONS]"
    puts
    puts "Options:"
    puts "  --json       Output JSON for CI/comparison"
    puts "  --quick      Quick run (shorter measurement time)"
    puts "  --scenarios  Run detailed scenario comparisons"
    puts "  --help       Show this help"
    exit 0
  end

  benchmark = IPSBenchmark.new(json_output: json_output, quick: quick)

  if scenarios
    benchmark.run_scenarios
  else
    benchmark.run
  end
end
