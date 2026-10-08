# frozen_string_literal: true

module BenchmarkReport
  FORMAT_NAMES = { "oas2" => "OpenAPI 2.0", "oas3" => "OpenAPI 3.0", "oas31" => "OpenAPI 3.1" }.freeze

  def self.median(samples)
    return nil if samples.nil? || samples.empty?

    sorted = samples.sort
    midpoint = sorted.size / 2
    sorted.size.odd? ? sorted[midpoint] : (sorted[midpoint - 1] + sorted[midpoint]) / 2.0
  end

  def self.change(current, baseline)
    return nil unless current && baseline&.positive?

    ((current.to_f / baseline) - 1) * 100
  end

  def self.rows(report, routes, format)
    medians = report.fetch("targets").map do |target|
      benchmark_case = target.fetch("cases", []).find { |entry| entry["routes"] == routes && entry["format"] == format }
      failed = target["error"] || benchmark_case&.fetch("error", nil)
      samples = failed ? nil : benchmark_case&.fetch("samples_ms", nil)
      { label: target.fetch("label"), sha: target.fetch("sha"), error: failed || (samples ? nil : "No samples"),
        median: median(samples), min: samples&.min, max: samples&.max }
    end
    medians.each_with_index do |row, index|
      row[:previous] = index.positive? ? change(row[:median], medians[index - 1][:median]) : nil
      row[:baseline] = change(row[:median], medians.first[:median]) if index.positive?
    end
    medians
  end

  def self.number(value)
    value ? Kernel.format("%.2f", value) : "—"
  end

  def self.percent(value)
    value ? Kernel.format("%+.1f%%", value) : "—"
  end

  def self.markdown(report)
    lines = ["# grape-oas generation benchmarks", "", "Generated: #{report.fetch("generated_at")}",
             "Ruby: #{report.fetch("environment").fetch("ruby")}", "",
             "Lower milliseconds are better. Negative changes mean faster generation.", ""]
    report.fetch("methodology").fetch("routes").each do |routes|
      FORMAT_NAMES.each do |format, name|
        lines.push("## #{routes} routes · #{name}", "", "Version | Median ms | Range ms | vs previous | vs oldest",
                   "--- | ---: | ---: | ---: | ---:",)
        table_rows = rows(report, routes, format)
        table_rows.each do |row|
          lines << ["#{row[:label]} (#{row[:sha][0, 8]})", number(row[:median]), "#{number(row[:min])}–#{number(row[:max])}",
                    percent(row[:previous]), percent(row[:baseline])].join(" | ")
        end
        lines << ""
        table_rows.select { |row| row[:error] }.each do |row|
          lines << "Failure for #{row[:label]}: #{row[:error].gsub(/\s+/, " ")}"
        end
        lines << ""
      end
    end
    methodology = report.fetch("methodology")
    lines.push("## Methodology", "",
               "#{methodology.fetch("warmup")} warmup generation; #{methodology.fetch("iterations")} measured generations per case.",
               "Case budget: #{methodology.fetch("case_timeout_seconds")} seconds. Timed-out cases have no partial timings or comparisons.",
               "Harness: #{report.fetch("harness_sha")}",
               methodology.fetch("operation"), "", "Environment and exact dependencies:", "", "```json",
               JSON.pretty_generate(report.fetch("environment")), "```", "",)
    lines.join("\n")
  end
end
