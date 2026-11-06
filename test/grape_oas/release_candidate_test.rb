# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "yaml"

class ReleaseCandidateTest < Minitest::Test
  SCRIPT = File.expand_path("../../.github/scripts/release_candidate.rb", __dir__)
  VERSION_FILE = "lib/grape_oas/version.rb"
  CHANGELOG = "# Changelog\n\n## [Unreleased]\n\n* New feature\n\n## [1.6.0] - 2026-09-21\n\n* Older feature\n"

  def setup
    @directory = Dir.mktmpdir("release-candidate-")
    @environment = {
      "GIT_CONFIG_GLOBAL" => File::NULL, "GIT_CONFIG_NOSYSTEM" => "1",
      "GIT_AUTHOR_NAME" => "Fixture", "GIT_AUTHOR_EMAIL" => "fixture@example.invalid",
      "GIT_COMMITTER_NAME" => "Fixture", "GIT_COMMITTER_EMAIL" => "fixture@example.invalid"
    }
    git("init", "-q")
    git("config", "commit.gpgsign", "false")
    FileUtils.mkdir_p(File.join(@directory, "lib/grape_oas"))
    write(VERSION_FILE, version_file("1.6.1"))
    write("CHANGELOG.md", CHANGELOG)
    commit("Base")
    @base = git("rev-parse", "HEAD").strip
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_rejects_code_added_at_tag_and_reverted_before_branch_tip
    prepare_candidate do |phase|
      path = File.join(@directory, "lib/grape_oas/unexpected.rb")
      phase == :release ? File.write(path, "# Unexpected packaged code\n") : File.delete(path)
    end
    _stdout, stderr, status = verify

    refute_predicate status, :success?, "Accepted an altered release tree: #{stderr}"
  end

  def test_accepts_a_release_and_next_iteration
    prepare_candidate
    stdout, stderr, status = verify

    assert_predicate status, :success?, stderr
    assert_equal "1.7.0\n", stdout
  end

  def test_rejects_ruby_code_appended_to_the_allowed_version_file
    prepare_candidate do
      File.open(File.join(@directory, VERSION_FILE), "a") { |file| file.puts 'File.write("executed", "bad")' }
    end
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
    refute_path_exists File.join(@directory, "executed")
  end

  def test_rejects_a_tag_outside_the_release_chain
    prepare_candidate
    tree = git("rev-parse", "v1.7.0^{tree}").strip
    unrelated = git("commit-tree", tree, "-m", "Unrelated").strip
    git("tag", "-f", "v1.7.0", unrelated)
    rebuild_bundle
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
  end

  def test_rejects_extra_commits_even_when_the_final_tree_is_unchanged
    prepare_candidate
    git("checkout", "-q", "release-prepared")
    git("commit", "--allow-empty", "-qm", "Extra commit")
    rebuild_bundle
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
  end

  def test_rejects_a_version_file_symlink_at_the_release_tag
    prepare_candidate do |phase|
      File.delete(File.join(@directory, VERSION_FILE))
      if phase == :release
        File.symlink("../../CHANGELOG.md", File.join(@directory, VERSION_FILE))
      else
        write(VERSION_FILE, version_file("1.7.1"))
      end
    end
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
  end

  def test_rejects_rewritten_historical_changelog_entries
    prepare_candidate do
      path = File.join(@directory, "CHANGELOG.md")
      File.write(path, File.read(path).sub("Older feature", "Altered history"))
    end
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
  end

  def test_rejects_a_multiline_version
    _stdout, stderr, status = verify("version", "1.7.0\n1.8.0")

    refute_predicate status, :success?, stderr
  end

  def test_rejects_an_existing_changelog_version
    write("CHANGELOG.md", "#{CHANGELOG}\n## [1.7.0] - 2026-11-05\n")
    commit("Already prepared")
    @base = git("rev-parse", "HEAD").strip
    _stdout, stderr, status = verify("version")

    refute_predicate status, :success?, stderr
    assert_includes stderr, "already contains version"
  end

  def test_uses_the_dispatch_version_when_no_version_was_requested
    stdout, stderr, status = verify("version", "")

    assert_predicate status, :success?, stderr
    assert_equal "1.6.1\n", stdout
  end

  def test_ci_skips_only_a_verified_release_pair
    prepare_candidate
    expected = @base
    @base = git("rev-parse", "release-prepared").strip
    stdout, stderr, status = verify("ci-base")

    assert_predicate status, :success?, stderr
    assert_equal expected, stdout.strip
  end

  def test_ci_does_not_skip_a_commit_with_a_forged_bot_author
    @environment["GIT_AUTHOR_NAME"] = "github-actions[bot]"
    write("README.md", "Changed code documentation\n")
    commit("Unverified bot commit")
    @base = git("rev-parse", "HEAD").strip
    stdout, stderr, status = verify("ci-base")

    assert_predicate status, :success?, stderr
    assert_equal @base, stdout.strip
  end

  def test_rejects_a_directory_in_place_of_a_bundle
    FileUtils.mkdir_p(File.join(@directory, "candidate.bundle"))
    _stdout, stderr, status = verify

    refute_predicate status, :success?, stderr
    assert_includes stderr, "regular git bundle"
  end

  def test_clean_consumers_verify_before_building_or_authenticating
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/release.yml", __dir__))
    { "package" => "Build the gem from the release tag",
      "publish" => "Authenticate to RubyGems with trusted publishing" }.each do |job, sink|
      steps = workflow.fetch("jobs").fetch(job).fetch("steps")
      verifier = steps.index { |step| step["name"] == "Verify release candidate" }
      consumer = steps.index { |step| step["name"] == sink }

      refute_nil verifier, "#{job} has no independent verification"
      assert_operator verifier, :<, consumer
      assert_equal "${{ inputs.version }}", steps[verifier].fetch("env").fetch("REQUESTED_VERSION")
      assert_includes steps[verifier].fetch("run"), "release_candidate.rb verify"
    end
  end

  def test_publish_downloads_the_immutable_package_id_from_the_clean_job
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/release.yml", __dir__))
    package = workflow.fetch("jobs").fetch("package")
    published = workflow.fetch("jobs").fetch("publish").fetch("steps")
    download = published.find { |step| step["name"] == "Download the release package" }

    assert_equal "${{ steps.upload.outputs.artifact-id }}", package.fetch("outputs", {})["artifact_id"]
    assert_equal "${{ needs.package.outputs.artifact_id }}", download.fetch("with")["artifact-ids"]
    refute download.fetch("with").key?("name")

    prepare = workflow.fetch("jobs").fetch("prepare")

    assert_equal "${{ steps.upload.outputs.artifact-id }}", prepare.fetch("outputs")["bundle_id"]
    %w[package publish].each do |job|
      steps = workflow.fetch("jobs").fetch(job).fetch("steps")
      bundle = steps.find { |step| step["name"] == "Download the release commits" }

      assert_equal "${{ needs.prepare.outputs.bundle_id }}", bundle.fetch("with")["artifact-ids"]
      refute bundle.fetch("with").key?("name")
    end
  end

  private

  def prepare_candidate
    git("checkout", "-qb", "release-prepared")
    write(VERSION_FILE, version_file("1.7.0"))
    @release_changelog = CHANGELOG.sub("## [Unreleased]", "## [1.7.0] - 2026-11-06")
    write("CHANGELOG.md", @release_changelog)
    yield :release if block_given?
    commit("Release")
    git("tag", "-a", "v1.7.0", "-m", "Release")
    write(VERSION_FILE, version_file("1.7.1"))
    write("CHANGELOG.md", @release_changelog.sub("## [1.7.0]", "\n## [Unreleased]\n\n* Your contribution here\n\n## [1.7.0]"))
    yield :next if block_given?
    commit("Next iteration")
    rebuild_bundle
  end

  def rebuild_bundle
    git("bundle", "create", "candidate.bundle", "release-prepared", "v1.7.0")
    git("checkout", "--detach", @base)
  end

  def verify(mode = "verify", version = "1.7.0")
    Open3.capture3(@environment.merge("GITHUB_SHA" => @base, "REQUESTED_VERSION" => version),
                   RbConfig.ruby, SCRIPT, mode, File.join(@directory, "candidate.bundle"), chdir: @directory,)
  end

  def version_file(version)
    "# frozen_string_literal: true\n\nmodule GrapeOAS\n  VERSION = \"#{version}\"\nend\n"
  end

  def write(path, content)
    File.write(File.join(@directory, path), content)
  end

  def commit(message)
    paths = git("ls-files", "--modified", "--deleted", "--others", "--exclude-standard", "-z").split("\0")
    git("add", "--", *paths)
    git("commit", "-qm", message)
  end

  def git(*)
    stdout, stderr, status = Open3.capture3(@environment, "git", *, chdir: @directory)
    raise stderr unless status.success?

    stdout
  end
end
