# Releasing Grape::OAS

This document describes the release process for the grape-oas gem.

## Pre-Release Checks

Before releasing, ensure:

1. All tests pass locally and in CI:
   ```bash
   bundle install
   bundle exec rake
   ```

2. The CHANGELOG.md is up to date with all changes since the last release.

3. The version number in `lib/grape_oas/version.rb` is correct.

## Release with the workflow

One-time setup:

1. Create a GitHub environment named `release`, restricted to `main`.
2. Add a RubyGems trusted publisher for the gem: owner `numbata`, repository `grape-oas`, workflow `release.yml`, environment `release`.
3. Allow the Actions bot to push directly to `main`.
4. Set the `RELEASERS` repository variable to the GitHub usernames allowed to release, space-separated (`gh variable set RELEASERS --body "numbata"`). An empty variable blocks every release.
5. Optional: add the `COPILOT_PAT` secret (a fine-grained token with the "Copilot Requests" permission) for the release introduction. Without it the draft has the changelog only.

Release by putting the notes under `## [Unreleased]` in `CHANGELOG.md`, then running the Release workflow on `main`:

```bash
gh workflow run release.yml --ref main                  # release the version in version.rb
gh workflow run release.yml --ref main -f version=1.7.0 # release an explicit version
gh workflow run release.yml --ref main -f dry_run=true  # run every check and prepare, publish nothing
```

The `prepare` job checks the actor, version, changelog notes, that CI passed on the latest human commit and that the version is not yet tagged or on RubyGems. It then runs the specs and lint and writes the release commit and the next-iteration commit, and it uploads them as the `release-commits` artifact. Only the version file and the changelog may change. The `intro` job drafts the Copilot introduction, and the `publish` job, the only one with RubyGems credentials, pushes the gem, then the commits and the tag, then creates a **draft** GitHub release. Review and publish the draft.

A dry run stops before publishing, so it does not exercise the final push to `main`; the first real release does.

### Recovering a partial release

- **Failed before "Push gem to RubyGems":** nothing was published or pushed. Fix the cause and run the workflow again.
- **Gem published, but the push to main failed:** download `release-commits`, then from a clone of `main` that has not moved:
  ```bash
  git fetch release.bundle 'release-prepared:release-prepared' vX.Y.Z
  git push --atomic origin release-prepared:main vX.Y.Z
  ```
  If `main` moved, run `git merge release-prepared`, resolve `CHANGELOG.md` and `lib/grape_oas/version.rb` keeping the dated release section and the next version, then push `HEAD:main vX.Y.Z`.
- **Tag and gem exist, but no GitHub release:** create the draft with `gh release create vX.Y.Z --draft --notes-file <notes> grape-oas-X.Y.Z.gem`, writing the notes by hand.

## Release Steps

### Automated Release Process

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
