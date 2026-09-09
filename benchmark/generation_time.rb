# frozen_string_literal: true

require "bundler/setup"
require "grape_oas"

ITERATIONS = Integer(ENV.fetch("ITERATIONS", 5))
ROUTE_COUNTS = ENV.fetch("ROUTE_COUNTS", "100,500,1000").split(",").map { |count| Integer(count) }.freeze
SCHEMA_TYPES = %i[oas2 oas3 oas31].freeze

abort "ITERATIONS and ROUTE_COUNTS must be positive" if ITERATIONS < 1 || ROUTE_COUNTS.any? { |count| count < 1 }

def build_api(route_count)
  Class.new(Grape::API) do
    format :json

    route_count.times do |index|
      params do
        requires :id, type: Integer
        optional :filter, type: String
      end
      get("items/#{index}/:id") { {} }
    end
  end
end

def measure(api, route_count, schema_type)
  document = GrapeOAS.generate(app: api, schema_type: schema_type)
  abort "Expected #{route_count} paths, got #{document.fetch("paths").size}" unless document.fetch("paths").size == route_count

  Array.new(ITERATIONS) do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    GrapeOAS.generate(app: api, schema_type: schema_type)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
  end
end

def median(samples)
  sorted = samples.sort
  midpoint = sorted.size / 2
  return sorted[midpoint] if sorted.size.odd?

  (sorted[midpoint - 1] + sorted[midpoint]) / 2
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Grape: #{Grape::VERSION}"
puts "Iterations: #{ITERATIONS}"
puts "routes\tdialect\tmedian_ms"

ROUTE_COUNTS.each do |route_count|
  api = build_api(route_count)
  SCHEMA_TYPES.each do |schema_type|
    puts "#{route_count}\t#{schema_type}\t#{format("%.2f", median(measure(api, route_count, schema_type)))}"
  end
end
