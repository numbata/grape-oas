---
name: grape-oas-pr-description
description: Write a grape-oas PR description following the project's required template — Problem, Fix, Example (a minimal Grape API snippet), Schema before / after, Backward compatibility, optional Open questions. Use when the user asks for a PR body or commit-message-style summary on grape-oas changes, when running `gh pr create` for grape-oas, and in autonomous "fix the code and push a PR" workflows where the agent must produce the PR body without further user input. Output is a single Markdown block ready to paste into the PR body.
---

# Generate a grape-oas PR description

Write a PR description for the diff in scope (current branch by
default) following
[agents/pr-description.md](../../../agents/pr-description.md).

Steps:

1. Inspect the diff. Default: `git diff main...HEAD`. If a different
   range is in scope, use that.
2. Identify which exporter / introspector / type-resolver paths are
   affected and which OAS versions (2.0, 3.0, 3.1) are impacted.
3. Write the PR body with all required sections in order: **Problem**,
   **Fix**, **Example**, **Schema before / after**, **Backward
   compatibility**, **Open questions** (optional).
4. The Schema before / after section is mandatory. If the change
   provably does not affect emitted output (a pure refactor, docs
   change, CI tweak), say so explicitly using the template from the
   "When the schema-before-after section can't be filled" section of
   `agents/pr-description.md`. Do not omit the section silently.
5. Use a minimal Grape API snippet (under ~15 lines) for the Example
   section. Strip everything not load-bearing.
6. Remind the user that the CHANGELOG entry lands *after* the PR is
   opened (it requires the PR number). Format:
   `- [#N](https://github.com/numbata/grape-oas/pull/N): summary -
   [@<handle>](https://github.com/<handle>).` under the appropriate
   `### Added` / `### Fixed` / `### Changed` subsection of
   `## [Unreleased]`. Danger warns when `CHANGELOG.md` is
   unmodified and fails when any line breaks Keep-a-Changelog
   format.

Do not include a test plan, "🤖 Generated with…" footers, or
`Co-Authored-By: Claude` lines. Do not list every touched file. Do
not restate the diff in prose.

Output the PR body as a single Markdown block. Do not commit or push
anything.
