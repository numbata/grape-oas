# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

BENCHMARK_BASELINE_PATH = "benchmark/baseline.json"

namespace :benchmark do
  desc "Run IPS benchmark (iterations per second)"
  task :ips do
    sh "bundle exec ruby benchmark/ips_benchmark.rb"
  end

  desc "Run quick IPS benchmark"
  task :quick do
    sh "bundle exec ruby benchmark/ips_benchmark.rb --quick"
  end

  desc "Run IPS benchmark with detailed scenarios"
  task :scenarios do
    sh "bundle exec ruby benchmark/ips_benchmark.rb --scenarios"
  end

  desc "Run IPS benchmark and output JSON for CI"
  task :ci do
    sh "bundle exec ruby benchmark/ips_benchmark.rb --json"
  end

  desc "Save current benchmark results as baseline"
  task :save do
    sh "bundle exec ruby benchmark/ips_benchmark.rb --json > #{BENCHMARK_BASELINE_PATH}"
    puts "Baseline saved to #{BENCHMARK_BASELINE_PATH}"
  end

  desc "Compare current results with baseline"
  task :compare do
    require "tempfile"

    abort "No baseline found. Run 'rake benchmark:save' first." unless File.exist?(BENCHMARK_BASELINE_PATH)

    current = Tempfile.new(["benchmark", ".json"])
    sh "bundle exec ruby benchmark/ips_benchmark.rb --json > #{current.path}"
    sh "bundle exec ruby benchmark/compare.rb #{BENCHMARK_BASELINE_PATH} #{current.path}"
    current.unlink
  end

  desc "Run memory profiling benchmark (use ITERATIONS=N to adjust, FORMAT=json|markdown|text)"
  task :memory do
    format = ENV.fetch("FORMAT", "text")
    flag = case format
           when "json" then "--json"
           when "markdown", "md" then "--markdown"
           else ""
           end
    sh "bundle exec ruby benchmark/memory_profile.rb #{flag}"
  end

  desc "Run memory benchmark and save markdown report"
  task :memory_report do
    sh "bundle exec ruby benchmark/memory_profile.rb --markdown > benchmark/memory_report.md"
    puts "Report saved to benchmark/memory_report.md"
  end

  desc "Run CPU profiling (requires stackprof gem)"
  task :cpu do
    iterations = ENV.fetch("ITERATIONS", "50")
    sh "bundle exec ruby benchmark/cpu_profile.rb --iterations=#{iterations}"
  end

  desc "Generate flamegraph for speedscope (requires stackprof gem)"
  task :flamegraph do
    iterations = ENV.fetch("ITERATIONS", "50")
    sh "bundle exec ruby benchmark/cpu_profile.rb --flamegraph --iterations=#{iterations}"
  end

  desc "Run all benchmarks (IPS + memory)"
  task all: %i[ips memory]
end

desc "Run IPS benchmarks"
task benchmark: "benchmark:ips"

namespace :release do
  desc "Pre-release actions (update CHANGELOG with version and date)"
  task :prerelease do
    require "date"

    version_file = "lib/grape_oas/version.rb"
    changelog_file = "CHANGELOG.md"

    # Read current version
    version_content = File.read(version_file)
    current_version = version_content[/VERSION = "(.+)"/, 1]

    abort "Error: Could not parse version from #{version_file}" unless current_version

    # Read CHANGELOG
    changelog_content = File.read(changelog_file)

    # Check if this version already exists in CHANGELOG (idempotent)
    if changelog_content.match?(/^## \[#{Regexp.escape(current_version)}\]/)
      puts "✓ CHANGELOG already contains version #{current_version}"
      puts "\n✓ No changes needed (already prepared for release)"
      exit 0
    end

    # Check if Unreleased section exists
    abort "Error: No 'Unreleased' section found in #{changelog_file}" unless changelog_content.match?(/^## \[Unreleased\]/)

    # Get today's date
    today = Date.today.strftime("%Y-%m-%d")

    # Replace Unreleased with version and date
    new_changelog = changelog_content.gsub(
      /^## \[Unreleased\]/,
      "## [#{current_version}] - #{today}",
    )

    # Remove "Your contribution here" placeholder lines
    new_changelog.gsub!(/^\s*-?\s*Your contribution here\.?\s*$/i, "")

    File.write(changelog_file, new_changelog)

    puts "Preparing release v#{current_version}"
    puts "✓ Updated #{changelog_file} (Unreleased → #{current_version})"
    puts "✓ Set release date to #{today}"

    # Stage and commit
    system("git add #{changelog_file}")

    # Only commit if there are staged changes
    if system("git diff --cached --quiet")
      puts "\n✓ No changes to commit"
    elsif system("git commit -m \"Preparing for release v#{current_version}\"")
      puts "\n✓ Changes committed successfully"
      puts "\nNext steps:"
      puts "  1. Review the commit: git show"
      puts "  2. Push to remote: git push origin main"
      puts "  3. Create release: bundle exec rake release"
    else
      abort "Error: Failed to commit changes"
    end
  end

  desc "Post-release actions (bump version, ensure Unreleased section)"
  task :postrelease do
    version_file = "lib/grape_oas/version.rb"
    changelog_file = "CHANGELOG.md"

    # Read current version
    version_content = File.read(version_file)
    current_version = version_content[/VERSION = "(.+)"/, 1]

    abort "Error: Could not parse version from #{version_file}" unless current_version

    # Increment patch version
    major, minor, patch = current_version.split(".").map(&:to_i)
    new_version = "#{major}.#{minor}.#{patch + 1}"

    puts "Bumping version: #{current_version} → #{new_version}"

    # Update version file
    new_version_content = version_content.gsub(
      /VERSION = "#{Regexp.escape(current_version)}"/,
      %(VERSION = "#{new_version}"),
    )
    File.write(version_file, new_version_content)
    puts "✓ Updated #{version_file}"

    # Ensure CHANGELOG has Unreleased section (idempotent)
    changelog_content = File.read(changelog_file)

    unreleased_section = "## [Unreleased]\n\n* Your contribution here\n"

    if changelog_content.match?(/^## \[Unreleased\]/)
      puts "✓ CHANGELOG already has Unreleased section"
    else
      # Insert Unreleased section after the header
      lines = changelog_content.lines
      header_end_index = lines.index { |line| line.match?(/^## \[\d/) } || 8

      lines.insert(header_end_index, "\n#{unreleased_section}\n")
      File.write(changelog_file, lines.join)
      puts "✓ Added Unreleased section to #{changelog_file}"
    end

    # Stage and commit changes
    system("git add #{version_file} #{changelog_file}")

    # Only commit if there are staged changes
    if system("git diff --cached --quiet")
      puts "\n✓ No changes to commit (already prepared)"
    elsif system('git commit -m "Prepare for next development iteration"')
      puts "\n✓ Changes committed successfully"
      puts "\nReminder: Push to remote with: git push origin main"
    else
      abort "Error: Failed to commit changes"
    end
  end
end

task default: %i[test rubocop]
