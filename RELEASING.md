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

## Release Steps

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

## Post-Release

1. **Prepare for next development cycle**:
   - Add "Unreleased" section to CHANGELOG.md
   - Bump version in `lib/grape_oas/version.rb`

2. **Commit post-release changes**:
   ```bash
   git add CHANGELOG.md lib/grape_oas/version.rb
   git commit -m "Prepare for next development iteration"
   git push origin main
   ```

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality in a backward compatible manner
- **PATCH**: Backward compatible bug fixes
