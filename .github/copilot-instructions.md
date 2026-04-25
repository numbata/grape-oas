# Copilot instructions for grape-oas

Primary contributor guidance lives in [AGENTS.md](../AGENTS.md). Read it
first.

## Copilot-specific notes

- When suggesting changes to `lib/`, pair them with tests under `test/`.
- Use **Minitest**, not RSpec. No `let`, `describe`, or `context`.
- Add a line under `## [Unreleased]` in `CHANGELOG.md` for
  user-visible changes (as a follow-up commit after the PR is opened
  — the project convention requires the PR number). Danger warns
  when `CHANGELOG.md` is unmodified and fails when any line breaks
  Keep-a-Changelog format.
- Run `bundle exec rake` (test + rubocop) before opening a PR.
- For PR descriptions, follow
  [agents/pr-description.md](../agents/pr-description.md). The
  **Schema before/after** section is required.
- For code review, follow [agents/code-review.md](../agents/code-review.md).
