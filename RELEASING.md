# Releasing Grape::OAS

This document describes the release process for the grape-oas gem.

## One-time setup

Publishing uses [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/); no API key or OTP is stored.

1. Create a GitHub environment named `release`, restricted to deployments from `main`. Required reviewers are optional.
2. As a gem owner, add a GitHub Actions trusted publisher on the gem's RubyGems.org page: owner `numbata`, repository `grape-oas`, workflow `release.yml`, environment `release`.
3. Allow the Actions bot to push directly to `main`.
4. Set the `RELEASERS` repository variable to the space-separated GitHub usernames allowed to release, e.g. `gh variable set RELEASERS --body "numbata"`. A missing or empty variable blocks every release.
5. Optional, for the release-notes introduction: add a repository secret `COPILOT_PAT`, a fine-grained personal access token of a user with a Copilot licence (with the "Copilot Requests" permission). Without it the draft contains the changelog entries only.

## Release with the workflow

Make sure `CHANGELOG.md` has the notes under `## [Unreleased]`, then run the
[Release workflow](https://github.com/numbata/grape-oas/actions/workflows/release.yml) on `main`:

```bash
gh workflow run release.yml --ref main                  # release the version in version.rb
gh workflow run release.yml --ref main -f version=1.7.0 # release an explicit version
gh workflow run release.yml --ref main -f dry_run=true  # run every check and build, publish nothing
```

A dry run is the safe way to try the workflow: it checks, prepares and tests the release, builds the gem and shows the notes draft in the run summary, then stops before authenticating to RubyGems. Nothing is tagged, pushed or published.

The workflow checks that the actor is in `RELEASERS`, that the version is not yet a tag or RubyGems version and is greater than the latest tag, then dates the changelog, runs the tests and RuboCop, builds the gem, publishes it to RubyGems, pushes the release commit and `vX.Y.Z` tag, creates a **draft** GitHub release, and bumps the patch version for the next iteration.

The draft contains an introduction written by a pinned Copilot CLI (capped at 50 AI credits per run) in a separate job that holds none of the publishing credentials, from the changelog (it falls back to the changelog alone if the Copilot call fails or `COPILOT_PAT` is not set), the changelog entries, a thanks line for contributors other than `numbata` and bots, and the full-changelog link. Review and edit the draft, then publish it.

If a run fails after the gem was published, the `release-vX.Y.Z` artifact holds the built gem and a git bundle with the prepared commit and tag for manual recovery.

## Release manually

### Pre-Release Checks

Before releasing, ensure:

1. All tests pass locally and in CI:
   ```bash
   bundle install
   bundle exec rake
   ```

2. The CHANGELOG.md is up to date with all changes since the last release.

3. The version number in `lib/grape_oas/version.rb` is correct.

### Release Steps

The manual steps below do not create a GitHub release or release notes; add them yourself on GitHub afterwards.

1. **Update the version** in `lib/grape_oas/version.rb` to the release version

2. **Prepare the CHANGELOG**:
   ```bash
   bundle exec rake release:prerelease
   ```
   This task will:
   - Replace "Unreleased" with the version number and today's date
   - Remove any "Your contribution here" placeholder lines
   - Commit with message "Preparing for release vX.X.X"

   **Note**: The task is idempotent - safe to run multiple times.

3. **Push and create the release**:
   ```bash
   git push origin main
   bundle exec rake release
   ```
   This will:
   - Build the gem
   - Create a git tag
   - Push the tag to GitHub
   - Push the gem to RubyGems.org

<details>
<summary>Manual Release Steps (if needed)</summary>

1. **Update CHANGELOG.md**
   - Change "Unreleased" to the version number and date
   - Remove any "Your contribution here" placeholder lines

2. **Commit the release preparation**:
   ```bash
   git add CHANGELOG.md
   git commit -m "Preparing for release v0.x.x"
   git push origin main
   ```

3. **Create and push the release**:
   ```bash
   bundle exec rake release
   ```
   This will:
   - Build the gem
   - Create a git tag
   - Push the tag to GitHub
   - Push the gem to RubyGems.org
</details>

## Post-Release

You can automate the post-release preparation with:

```bash
bundle exec rake release:postrelease
git push origin main
```

This task will:
- Bump the patch version in `lib/grape_oas/version.rb`
- Ensure CHANGELOG.md has an "Unreleased" section with "* Your contribution here" placeholder
- Commit the changes with message "Prepare for next development iteration"

**Note**: The task is idempotent - safe to run multiple times without duplicating work.

<details>
<summary>Manual Post-Release Steps (if needed)</summary>

1. **Prepare for next development cycle**:
   - Add "Unreleased" section to CHANGELOG.md with "* Your contribution here" placeholder
   - Bump version in `lib/grape_oas/version.rb`

2. **Commit post-release changes**:
   ```bash
   git add CHANGELOG.md lib/grape_oas/version.rb
   git commit -m "Prepare for next development iteration"
   git push origin main
   ```
</details>

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality in a backward compatible manner
- **PATCH**: Backward compatible bug fixes
