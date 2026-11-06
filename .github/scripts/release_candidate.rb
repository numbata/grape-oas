# frozen_string_literal: true

require "date"
require "open3"

class ReleaseCandidate
  class Invalid < StandardError; end

  VERSION = /\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\z/
  VERSION_FILE = "lib/grape_oas/version.rb"
  ALLOWED_FILES = [VERSION_FILE, "CHANGELOG.md"].freeze

  def initialize
    @base = ENV.fetch("GITHUB_SHA")
    raise Invalid, "Invalid dispatch SHA" unless @base.match?(/\A[0-9a-f]{40}\z/)
  end

  def version
    requested = ENV.fetch("REQUESTED_VERSION", "")
    requested = read_version(@base) if requested.empty?
    raise Invalid, "Expected MAJOR.MINOR.PATCH" unless VERSION.match?(requested)

    changelog = blob(@base, "CHANGELOG.md")
    raise Invalid, "CHANGELOG already contains version #{requested}" if changelog.match?(/^## \[#{Regexp.escape(requested)}\]/)
    raise Invalid, "Expected one Unreleased section" unless changelog.scan(/^## \[Unreleased\]/).one?

    notes = changelog.split(/^## \[Unreleased\]/, 2).last.split(/^## \[/, 2).first
    notes = notes.gsub(/^\s*[-*]?\s*Your contribution here\.?\s*$/i, "")
    notes = notes.gsub(/^ {0,3}\#{1,6}(?:[ \t]+.*)?$/, "")
    raise Invalid, "No notes under Unreleased" if notes.strip.empty?

    requested
  end

  def verify(bundle)
    release_version = version
    raise Invalid, "Expected a regular git bundle" unless File.lstat(bundle).file?

    git("bundle", "verify", bundle)
    git("fetch", "--no-tags", bundle, "refs/heads/release-prepared:refs/heads/release-prepared",
        "refs/tags/v#{release_version}:refs/tags/v#{release_version}",)
    release = git("rev-parse", "--verify", "refs/tags/v#{release_version}^{commit}").strip
    prepared = git("rev-parse", "--verify", "refs/heads/release-prepared^{commit}").strip
    verify_commits(@base, release, prepared, release_version)
    release_version
  end

  # Token-created release commits have no push CI run. Skip only fully verified release pairs, never author names.
  def ci_base
    tip = @base
    loop do
      release = git("rev-parse", "#{tip}^").strip
      base = git("rev-parse", "#{tip}~2").strip
      release_version = read_version(release)
      tag = git("rev-parse", "refs/tags/v#{release_version}^{commit}").strip
      break unless tag == release

      verify_commits(base, release, tip, release_version)
      tip = base
    rescue Invalid
      break
    end
    tip
  end

  private

  def verify_commits(base, release, prepared, release_version)
    raise Invalid, "Release must be one commit after the dispatch SHA" unless parents(release) == [base]
    raise Invalid, "Expected one next-iteration commit after the release" unless parents(prepared) == [release]

    original = blob(base, "CHANGELOG.md")
    date = blob(release, "CHANGELOG.md")[/^## \[#{Regexp.escape(release_version)}\] - (\d{4}-\d{2}-\d{2})$/, 1]
    raise Invalid, "Missing dated release section" unless date

    Date.iso8601(date)
    released = original.sub(/^## \[Unreleased\]/, "## [#{release_version}] - #{date}")
                       .gsub(/^\s*[-*]?\s*Your contribution here\.?\s*$/i, "")
    verify_tree(base, release, release_version, released)
    lines = released.lines
    index = lines.index { |line| line.match?(/^## \[\d/) }
    raise Invalid, "Missing release section" unless index

    lines.insert(index, "\n## [Unreleased]\n\n* Your contribution here\n\n")
    major, minor, patch = release_version.split(".").map(&:to_i)
    verify_tree(base, prepared, "#{major}.#{minor}.#{patch + 1}", lines.join)
  rescue Date::Error
    raise Invalid, "Invalid release date"
  end

  def verify_tree(base, ref, release_version, changelog)
    changed = git("diff", "--no-ext-diff", "--no-textconv", "--no-renames", "--name-only", "-z", base, ref).split("\0")
    raise Invalid, "Release changes files outside version.rb and CHANGELOG.md" unless (changed - ALLOWED_FILES).empty?

    ALLOWED_FILES.each do |path|
      raise Invalid, "Expected a regular file at #{path}" unless git("ls-tree", ref, "--", path).start_with?("100644 blob ")
    end
    read_version(base)
    expected = blob(base, VERSION_FILE).sub(/VERSION = "[^"]+"/, %(VERSION = "#{release_version}"))
    raise Invalid, "Unexpected version.rb content" unless blob(ref, VERSION_FILE) == expected
    raise Invalid, "Unexpected CHANGELOG content" unless blob(ref, "CHANGELOG.md") == changelog
  end

  def read_version(ref)
    content = blob(ref, VERSION_FILE)
    parsed = content[/\A# frozen_string_literal: true\n\nmodule GrapeOAS\n  VERSION = "([^"]+)"\nend\n\z/, 1]
    raise Invalid, "Unexpected version.rb template" unless parsed && VERSION.match?(parsed)

    parsed
  end

  def parents(ref)
    git("show", "--no-patch", "--format=%P", ref).split
  end

  def blob(ref, path)
    git("show", "#{ref}:#{path}")
  end

  def git(*)
    stdout, stderr, status = Open3.capture3({ "GIT_NO_REPLACE_OBJECTS" => "1" }, "git", *)
    raise Invalid, "Git verification failed: #{stderr.strip}" unless status.success?

    stdout
  end
end

begin
  candidate = ReleaseCandidate.new
  puts case ARGV.fetch(0)
       when "version" then candidate.version
       when "verify" then candidate.verify(ARGV.fetch(1))
       when "ci-base" then candidate.ci_base
       else abort "Unknown release candidate command"
       end
rescue ReleaseCandidate::Invalid => e
  abort "::error::#{e.message}"
end
