# frozen_string_literal: true

require "bundler/setup"
require "json"
require "grape_oas"

abort "YJIT must be disabled" if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
abort "ZJIT must be disabled" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?

route_counts = JSON.parse(ARGV.fetch(0))
iterations = Integer(ARGV.fetch(1))
cases = []
schema_types = %i[oas2 oas3 oas31]

route_counts.each do |route_count|
  warn "  Building #{route_count}-route API"
  api = Class.new(Grape::API) do
    format :json
    route_count.times do |index|
      params do
        requires :id, type: Integer
        optional :filter, type: String
      end
      get("items/#{index}/:id") { {} }
    end
  end

  schema_types.each do |schema_type|
    warn "  Measuring #{route_count} routes / #{schema_type}"
    benchmark_case = { "routes" => route_count, "format" => schema_type.to_s }
    begin
      document = GrapeOAS.generate(app: api, schema_type: schema_type)
      actual_count = document.fetch("paths").size
      raise "Expected #{route_count} paths, got #{actual_count}" unless actual_count == route_count

      benchmark_case["samples_ms"] = Array.new(iterations) do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        GrapeOAS.generate(app: api, schema_type: schema_type)
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
      end
    rescue StandardError => e
      benchmark_case["error"] = "#{e.class}: #{e.message}"
    end
    cases << benchmark_case
    warn "  Finished #{route_count} routes / #{schema_type}"
  end
end

puts JSON.generate(cases)
