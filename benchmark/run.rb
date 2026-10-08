# frozen_string_literal: true

require "bundler/setup"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rbconfig"
require "time"
require "tmpdir"

root = File.expand_path("..", __dir__)
options = {
  repo: File.expand_path("../../grape-oas", __dir__),
  refs: %w[v1.0.3 v1.1.0 v1.2.0 v1.3.0 v1.4.0 v1.5.1 v1.6.0 origin/main],
  routes: [100, 500, 1_000], iterations: 10, output: File.join(root, "results")
}
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby benchmark/run.rb [options]"
  parser.on("--repo PATH", "Local grape-oas repository") { |v| options[:repo] = File.expand_path(v) }
  parser.on("--refs LIST", Array, "Comma-separated tags or commit refs") { |v| options[:refs] = v }
  parser.on("--routes LIST", Array, "Comma-separated route counts") { |v| options[:routes] = v.map { |n| Integer(n) } }
  parser.on("--iterations N", Integer, "Measured generations after one warmup") { |v| options[:iterations] = v }
  parser.on("--output PATH", "Directory for raw reports") { |v| options[:output] = File.expand_path(v) }
end.parse!
abort "Refs, routes, and iterations must be nonempty and positive" if options[:refs].empty? || options[:routes].empty? ||
                                                                      options[:iterations] < 1 || options[:routes].any? { |n| n < 1 }

def capture!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  raise "#{command.first} failed: #{stderr.strip}" unless status.success?

  stdout.strip
end

started_at = Time.now.utc
lockfile = File.join(root, "Gemfile.lock")
report = {
  "generated_at" => started_at.iso8601,
  "harness_sha" => capture!("git", "-C", root, "rev-parse", "HEAD"),
  "harness_dirty" => !capture!("git", "-C", root, "status", "--porcelain", "--untracked-files=no").empty?,
  "harness_digest" => Digest::SHA256.hexdigest(Dir[File.join(root, "benchmark", "*.rb")].map { |path| File.read(path) }.join),
  "environment" => {
    "ruby" => RUBY_DESCRIPTION,
    "os" => capture!("uname", "-srm"),
    "cpu" => RUBY_PLATFORM.include?("darwin") ? capture!("sysctl", "-n", "machdep.cpu.brand_string") : RbConfig::CONFIG.fetch("host_cpu"),
    "jit" => "disabled",
    "dependencies" => Bundler.load.specs.to_h { |spec| [spec.name, spec.version.to_s] },
    "lockfile_sha256" => Digest::SHA256.file(lockfile).hexdigest
  },
  "methodology" => { "warmup" => 1, "iterations" => options[:iterations], "routes" => options[:routes],
                     "formats" => %w[oas2 oas3 oas31], "operation" => "GrapeOAS.generate; excludes API setup and JSON serialization" },
  "targets" => []
}

options[:refs].each do |ref|
  sha = capture!("git", "-C", options[:repo], "rev-parse", "--verify", "#{ref}^{commit}")
  target = { "label" => ref == "origin/main" ? "main" : ref, "sha" => sha }
  warn "Measuring #{target.fetch("label")} (#{sha[0, 8]})"
  Dir.mktmpdir("grape-oas-benchmark-") do |checkout|
    statuses = Open3.pipeline(["git", "-C", options[:repo], "archive", sha], ["tar", "-x", "-C", checkout])
    raise "Could not extract #{ref}" unless statuses.all?(&:success?)

    env = { "BUNDLE_GEMFILE" => File.join(root, "Gemfile"), "RUBYOPT" => nil,
            "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil, "RUBYLIB" => nil }
    jit_flags = ["--disable-yjit"]
    jit_flags << "--disable-zjit" if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("4.0")
    stdout = nil
    stderr = +""
    status = nil
    Open3.popen3(env, RbConfig.ruby, *jit_flags, "-I", File.join(checkout, "lib"),
                   File.join(__dir__, "worker.rb"), JSON.generate(options[:routes]), options[:iterations].to_s,) do |stdin, out, err, worker|
      stdin.close
      errors = Thread.new do
        err.each_line do |line|
          redacted = line.gsub(checkout, "<target>").gsub(root, "<harness>").gsub(Dir.home, "~")
          stderr << redacted
          warn redacted
        end
      end
      stdout = out.read
      errors.join
      status = worker.value
    end
    if status.success?
      target["cases"] = JSON.parse(stdout)
    else
      target["error"] = "Worker failed: #{stderr.strip}"
      warn target.fetch("error")
    end
  end
  report.fetch("targets") << target
end

FileUtils.mkdir_p(options[:output])
filename = File.join(options[:output], "#{started_at.strftime("%Y%m%dT%H%M%S")}-#{report.fetch("targets").last.fetch("sha")[0, 8]}.json")
raise "Report already exists: #{filename}" if File.exist?(filename)

File.write(filename, "#{JSON.pretty_generate(report)}\n")
puts filename
