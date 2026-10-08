# frozen_string_literal: true

require "cgi"
require "erb"
require "fileutils"
require "json"
require_relative "report"

class GemSite
  ROOT = File.expand_path("..", __dir__)

  attr_reader :config, :reports, :report, :report_name, :page, :title, :description

  def initialize
    @config = JSON.parse(File.read(File.join(ROOT, "site.json")))
    @reports = Dir[File.join(ROOT, "results", "*.json")].reverse.map do |path|
      [File.basename(path, ".json"), JSON.parse(File.read(path))]
    end
    @example = File.read(File.join(ROOT, "examples", "api.rb"))
  end

  def h(text)
    CGI.escapeHTML(text.to_s)
  end

  def url(path = "")
    "#{config.fetch("base_path")}/#{path}"
  end

  def repo(path = "")
    "#{config.fetch("repository")}/#{path}"
  end

  def docs(path)
    repo("blob/main/#{path}")
  end

  def code(source)
    "<pre tabindex=\"0\"><code>#{h(source.strip)}</code></pre>"
  end

  def template(name)
    ERB.new(File.read(File.join(ROOT, "site", "templates", "#{name}.erb"))).result(binding)
  end

  def build
    output = File.join(ROOT, "build", config.fetch("base_path").delete_prefix("/"))
    FileUtils.rm_rf(output)
    FileUtils.mkdir_p(File.join(output, "assets"))
    FileUtils.cp(Dir[File.join(ROOT, "site", "assets", "*")], File.join(output, "assets"))
    File.write(File.join(output, ".nojekyll"), "")
    render(output: output, directory: "", page: "home", title: "OpenAPI documentation for Grape APIs",
           description: "Generate OpenAPI 2.0, 3.0, and 3.1 documents from your Grape API.",)
    render(output: output, directory: "getting-started", page: "guide", title: "Getting started",
           description: "Install grape-oas, document a Grape API, and generate your first OpenAPI document.",)
    @report_name, @report = reports.first
    render(output: output, directory: "benchmarks", page: "benchmarks", title: "Release benchmarks",
           description: "Measured OpenAPI generation times across grape-oas releases and API sizes.",)
    reports.each do |name, raw_report|
      @report_name = name
      @report = raw_report
      directory = "benchmarks/runs/#{name}"
      render(output: output, directory: directory, page: "benchmarks", title: "Benchmark run #{name}",
             description: "Reproducible generation timings and environment details for this benchmark run.",)
      File.write(File.join(output, directory, "results.json"), "#{JSON.pretty_generate(raw_report)}\n")
      File.write(File.join(output, directory, "RESULTS.md"), BenchmarkReport.markdown(raw_report))
    end
    puts output
  end

  def render(output:, directory:, page:, title:, description:)
    @page = page
    @title = title
    @description = description
    @content = template(page)
    destination = File.join(output, directory)
    FileUtils.mkdir_p(destination)
    html = template("layout").lines.map(&:rstrip).join("\n")
    File.write(File.join(destination, "index.html"), "#{html}\n")
  end
end

GemSite.new.build if $PROGRAM_NAME == __FILE__
