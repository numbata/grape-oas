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

namespace :benchmark do
  desc "Run memory profiling benchmark (use ITERATIONS=N to adjust, FORMAT=json|markdown|text)"
  task :memory do
    format = ENV.fetch("FORMAT", "text")
    flag = case format
           when "json" then "--json"
           when "markdown", "md" then "--markdown"
           else ""
           end
    sh "ruby benchmark/memory_profile.rb #{flag}"
  end

  desc "Run memory benchmark and save markdown report"
  task :memory_report do
    sh "ruby benchmark/memory_profile.rb --markdown > benchmark/memory_report.md"
    puts "Report saved to benchmark/memory_report.md"
  end
end

task default: %i[test rubocop]
