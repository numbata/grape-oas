# frozen_string_literal: true

require "test_helper"
require "rake"

class RakefileTest < Minitest::Test
  def setup
    Rake::Task.clear
    load File.expand_path("../Rakefile", __dir__)
  end

  def test_prerelease_removes_contribution_placeholders
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "lib/grape_oas"))
      File.write(File.join(directory, "lib/grape_oas/version.rb"), %(VERSION = "1.6.0"\n))
      File.write(
        File.join(directory, "CHANGELOG.md"),
        "# Changelog\n\n## [Unreleased]\n\n* Your contribution here\n\n### Added\n\n- Added feature.\n",
      )

      Dir.chdir(directory) do
        system("git", "init", "--quiet")
        system("git", "config", "user.name", "Test")
        system("git", "config", "user.email", "test@example.com")
        system("git", "config", "commit.gpgsign", "false")
        capture_subprocess_io { Rake::Task["release:prerelease"].invoke }

        changelog = File.read("CHANGELOG.md")

        assert_includes changelog, "## [1.6.0]"
        refute_includes changelog, "Your contribution here"
      end
    end
  end
end
