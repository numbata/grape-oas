# AGENTS.md

Guidance for AI coding agents working on the **grape-oas** codebase.
Human contributors should read [README.md](README.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) first.

> If you find conflicting guidance elsewhere, **AGENTS.md wins**.

## What this gem is

`grape-oas` generates **OpenAPI Specification** documents (OAS 2.0, 3.0, and
3.1) from APIs built with the [Grape](https://github.com/ruby-grape/grape)
framework. It is built around a DTO architecture that separates *introspecting*
a Grape API from *exporting* the spec — the same internal API model can be
rendered to any of the three OAS versions.

It is **not** a fork or extension of `grape-swagger` (which only emits OAS 2.0).
Patterns from grape-swagger are usually wrong here. Scope is spec generation
only — no UI, no runtime request validation. Expanding scope requires an issue
first.

## Dev environment

- Ruby: `>= 3.2` (see `grape-oas.gemspec` `required_ruby_version`).
- Use `rbenv` to select Ruby. Prefix shell commands with
  `eval "$(rbenv init - bash)" &&` if your shell isn't initialized.
- Install: `bin/setup` (or `bundle install`).
- Run the full test suite: `bundle exec rake test`.
- Run one test file: `bundle exec rake test TEST=test/path/to/file_test.rb`.
- Run one example: `bundle exec ruby -Itest test/path/to/file_test.rb -n /pattern/`.
- Lint: `bundle exec rubocop`.
- Autofix safe cops: `bundle exec rubocop -a` (use `-A` only when you've
  reviewed the unsafe corrections).
- **Pre-PR check (run before opening a PR):** `bundle exec rake` — runs
  `test` then `rubocop`. CI runs both checks (rubocop in one job, then a
  Ruby × Grape matrix for tests).

This project uses **Minitest**, not RSpec. Do not introduce RSpec, `let`,
`describe`, or `context` — use `Minitest::Test` subclasses with `def test_*`
methods.

## Repo layout

```
lib/grape_oas/
  api_model/                 # DTOs: the in-memory representation of an API
  api_model_builders/        # Build the API model from a Grape app
  api_model_builder.rb       # Top-level builder entry point
  introspectors/             # Extract schemas from entities / contracts
                             # (grape-entity, dry-validation, dry-types)
  type_resolvers/            # Map Ruby/Grape types to OAS types
  exporter/                  # Render the API model as OAS 2.0 / 3.0 / 3.1
  rake/                      # Rake tasks shipped to consumers
  documentation_extension.rb # Mounts add_oas_documentation onto Grape::API
  schema_constraints.rb      # Constraint propagation helpers

test/
  grape_oas/                # Unit tests, mirrors lib/ structure
  integration/              # Cross-component tests
  e2e/                      # Full Grape API → JSON spec tests
  helpers/                  # Test-only helpers
  support/                  # Shared fixtures and matchers
  test_helper.rb

docs/                       # Reference documentation for users
agents/                     # Extended guidance for agents (read these)
```

## Conventions

- Every `.rb` file starts with `# frozen_string_literal: true`.
- Top-level namespace is `GrapeOAS` (not `Grape::OAS`).
- Public API = anything reachable from `GrapeOAS.<method>`, the
  `Grape::API`-mounted DSL (`add_oas_documentation`), plus classes
  documented in `docs/`. Everything else is internal — refactor freely.
- Prefer keyword arguments for new methods with several parameters
  (RuboCop allows up to 13 positional, but new methods past ~3 are
  hard to read at call sites). Existing positional-heavy methods like
  `add_documentation_routes` in `documentation_extension.rb` are
  exceptions, not patterns to copy.
- Generated OAS structures are plain `Hash` with **string keys** (per OAS
  spec). Do not use symbols in emitted output.
- Omit optional keys entirely instead of emitting `nil` / `null`.
- See [agents/conventions.md](agents/conventions.md) for file size,
  comments, naming, and "where new code goes" rules. Read it before
  adding new code.

## Testing rules

- Minitest only. New tests go under `test/`, mirroring `lib/` paths.
- Any new public method gets a test. Any bug fix gets a regression test
  that **fails on the parent commit and passes on this commit**.
- E2E tests under `test/e2e/` assert on full Grape-API → OAS-JSON output
  and are slow — prefer unit tests in `test/grape_oas/` when you can
  isolate the behavior.
- Reuse existing fixture Grape APIs in `test/support/` before adding new
  ones. Duplicate fixtures bloat suite runtime.
- Assert on structural subsets of generated JSON, not full equality,
  unless shape-fidelity is the test's whole point.

## Pull requests

- When **writing** a PR description, follow
  [agents/pr-description.md](agents/pr-description.md). The required
  sections (in order) are: **Problem**, **Fix**, **Example** (a minimal
  Grape API snippet), **Schema before / after**, **Backward
  compatibility**. Do not skip the schema diff — see the doc for the
  one allowed exception.
- When **reviewing** a PR (your own before opening it, or someone else's),
  follow [agents/code-review.md](agents/code-review.md). Claude users can
  invoke this with `/critique`.
- Add a `CHANGELOG.md` entry under `## [Unreleased]` for every
  user-visible change. The project convention is `[#N](url): summary
  - [@handle](url).`, which requires the PR number, so the entry
  lands *after* the PR is opened — push it as a follow-up commit.
  Danger warns when `CHANGELOG.md` is unmodified and fails when any
  line breaks Keep-a-Changelog format; the PR-numbered link form is
  one of two formats Danger accepts (the bare
  `* Capitalized summary - [@handle](url).` would also pass) and is
  project convention, not a Danger requirement. See
  [agents/pr-description.md](agents/pr-description.md) for the exact
  line format.
- Stage files specifically by name; never `git add -A` or `git add .`.
- Do not bump the gem version in feature PRs — version bumps happen at
  release time.
- Do not include test plans, agent attribution footers, or
  "🤖 Generated with…" lines in PR bodies or commit messages.

## Boundaries

- Do not commit credentials, RubyGems API keys, or `~/.gem/credentials`
  content.
- Do not modify `.github/workflows/`, `Dangerfile`, `Rakefile`, or release
  tasks (`namespace :release` in `Rakefile`) without explicit maintainer
  approval.
- Do not monkey-patch Grape classes from `lib/`. Extension points should
  be explicit modules (introspectors, exporters, type resolvers) that the
  user registers.
- Do not add runtime dependencies lightly. Each new entry in
  `grape-oas.gemspec` needs justification in the PR description.
- The `.serena/`, `.ruby-lsp/`, `coverage/`, `pkg/`, and `tmp/`
  directories are tool/build artifacts — do not commit changes inside
  them.

## Things an LLM will get wrong without being told

- **`grape-swagger` ≠ `grape-oas`.** Many Stack Overflow answers and blog
  posts conflate them. grape-swagger emits OAS 2.0 only and uses
  different internals. Do not import code or patterns from grape-swagger
  — adapt for OAS 3.x and this gem's DTO architecture instead.
- **OAS 3.0 vs 3.1 diverge.** OAS 3.0 uses `nullable: true` by
  default and an OpenAPI-specific JSON Schema dialect; OAS 3.1 uses
  `type: ["string", "null"]` and aligns with JSON Schema 2020-12.
  The exporter has separate code paths — when changing one, decide
  explicitly whether the other needs the same change. The
  `nullable_strategy:` option (`KEYWORD` / `TYPE_ARRAY`) is
  configurable for OAS 3.0; OAS 3.1 hard-overrides to `TYPE_ARRAY`
  regardless of the option (see
  `lib/grape_oas/exporter/oas31_schema.rb`), so a `nullable: true`
  in OAS 3.1 output is always a bug. OAS 2.0 nullable handling is
  underspecified (issue #91) — see `agents/code-review.md`.
- **Grape parameter DSL has non-standard syntax.** `requires :foo, type:
  Array[Integer]` is a Grape convention, not standard Ruby generics.
- **`$ref` and composition (`allOf` / `oneOf` / `anyOf`) drop attributes
  by default.** When changing schema rendering, check that attributes
  (`default`, `enum`, `format`, constraints, extensions) survive both
  paths. PR #70 documents the full attribute-survival matrix.
- **`bundle exec rake` is the validation gate**, not just `rake test`.
  The default task runs tests and RuboCop together; CI runs the same
  checks but splits them across a rubocop job and a Ruby × Grape test
  matrix.

## If you are unsure

Stop and ask in the PR rather than guessing. For unclear schema impact,
re-run the affected exporter against the e2e fixtures
(`bundle exec rake test TEST=test/e2e/...`) and paste the diff in your
question — that turns "I'm not sure" into a concrete review item.
