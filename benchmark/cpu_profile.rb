# frozen_string_literal: true

# benchmark/cpu_profile.rb
# CPU profiling with StackProf for finding performance hotspots
#
# Usage:
#   ruby benchmark/cpu_profile.rb                  # CPU profiling (text report)
#   ruby benchmark/cpu_profile.rb --flamegraph     # Generate flamegraph JSON
#   ruby benchmark/cpu_profile.rb --iterations=50  # Custom iteration count
#
# Output:
#   benchmark/profiles/cpu_*.txt         - Text report
#   benchmark/profiles/flamegraph_*.json - Flamegraph for speedscope
#
# View flamegraph:
#   npx speedscope benchmark/profiles/flamegraph_*.json
#   Or upload to https://www.speedscope.app/

require_relative "support/test_api"
require "fileutils"

PROFILES_DIR = File.expand_path("profiles", __dir__)

class CPUProfiler
  DEFAULT_ITERATIONS = 50

  def initialize(iterations: DEFAULT_ITERATIONS, flamegraph: false)
    @iterations = iterations
    @flamegraph = flamegraph
    @timestamp = Time.now.strftime("%Y%m%d_%H%M%S")

    FileUtils.mkdir_p(PROFILES_DIR)
  end

  def run
    require_stackprof!

    if @flamegraph
      generate_flamegraph
    else
      generate_text_report
    end
  end

  private

  def require_stackprof!
    require "stackprof"
  rescue LoadError
    warn "StackProf not found. Add to Gemfile:"
    warn "  gem 'stackprof', group: :development"
    exit 1
  end

  def workload
    @iterations.times do
      GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3)
    end
  end

  def generate_text_report
    dump_file = File.join(PROFILES_DIR, "cpu_#{@timestamp}.dump")
    text_file = File.join(PROFILES_DIR, "cpu_#{@timestamp}.txt")

    puts "Running CPU profiler..."
    puts "  Iterations: #{@iterations}"
    puts "  API endpoints: #{BenchmarkAPI.routes.size}"
    puts

    profile_data = StackProf.run(mode: :cpu, interval: 100, raw: true) do
      workload
    end

    # Save binary dump
    File.binwrite(dump_file, Marshal.dump(profile_data))

    # Generate text report
    report = StackProf::Report.new(profile_data)

    File.open(text_file, "w") do |f|
      f.puts "CPU Profile Report"
      f.puts "=" * 60
      f.puts "Generated: #{Time.now}"
      f.puts "Iterations: #{@iterations}"
      f.puts "Ruby: #{RUBY_VERSION}"
      f.puts "grape-oas: #{GrapeOAS::VERSION}"
      f.puts

      original_stdout = $stdout
      $stdout = f
      report.print_text
      $stdout = original_stdout
    end

    puts "Profile saved:"
    puts "  Text:   #{text_file}"
    puts "  Binary: #{dump_file}"
    puts
    puts "To generate flamegraph from binary:"
    puts "  stackprof --d3-flamegraph #{dump_file} > flamegraph.html"
    puts
    puts "Top 10 methods:"
    puts "-" * 60

    # Print top methods to console
    report.print_text(limit: 10)
  end

  def generate_flamegraph
    dump_file = File.join(PROFILES_DIR, "flamegraph_#{@timestamp}.dump")
    json_file = File.join(PROFILES_DIR, "flamegraph_#{@timestamp}.json")

    puts "Generating flamegraph data..."
    puts "  Iterations: #{@iterations}"
    puts

    profile_data = StackProf.run(mode: :cpu, interval: 100, raw: true) do
      workload
    end

    # Save binary dump
    File.binwrite(dump_file, Marshal.dump(profile_data))

    # Convert to flamegraph JSON using stackprof CLI
    result = system("stackprof --d3-flamegraph #{dump_file} > #{json_file} 2>/dev/null")

    if result && File.size?(json_file)
      puts "Flamegraph saved:"
      puts "  JSON: #{json_file}"
      puts
      puts "View with speedscope:"
      puts "  npx speedscope #{json_file}"
      puts
      puts "Or upload to: https://www.speedscope.app/"
    else
      # Fallback: create a simple JSON structure
      puts "Note: stackprof CLI not available, saving binary dump only"
      puts "  Binary: #{dump_file}"
      puts
      puts "Convert with:"
      puts "  stackprof --d3-flamegraph #{dump_file} > flamegraph.json"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.include?("--help") || ARGV.include?("-h")
    puts "Usage: ruby benchmark/cpu_profile.rb [OPTIONS]"
    puts
    puts "Options:"
    puts "  --flamegraph       Generate flamegraph JSON for speedscope"
    puts "  --iterations=N     Number of iterations (default: #{CPUProfiler::DEFAULT_ITERATIONS})"
    puts "  --help             Show this help"
    puts
    puts "Output files are saved to benchmark/profiles/"
    exit 0
  end

  flamegraph = ARGV.include?("--flamegraph")

  iterations = CPUProfiler::DEFAULT_ITERATIONS
  ARGV.each do |arg|
    iterations = arg.split("=").last.to_i if arg.start_with?("--iterations=")
  end

  profiler = CPUProfiler.new(iterations: iterations, flamegraph: flamegraph)
  profiler.run
end
