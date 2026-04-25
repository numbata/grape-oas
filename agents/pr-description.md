# Writing a PR description for grape-oas

Opinionated guide to writing a grape-oas PR description.

## Why these rules exist

grape-oas's whole job is to emit a specific OpenAPI Specification
document shape. Most reviews boil down to one question: **did the
emitted JSON/YAML change in the way the author intended, and did
anything else change by accident?** A PR description that doesn't show
the schema diff forces the reviewer to reconstruct it from the test
files, which is slow and error-prone. The required sections below are
all optimized for that question.

## Required structure

Going forward, grape-oas PR bodies should contain these sections, in
this order. Existing merged PRs predate this template — do not cite
them as proof a section is optional. The embedded worked example
below is the template's reference shape. Skip a section only if it
genuinely doesn't apply (most of the time, none of them should be
skipped).

````markdown
## Problem

One paragraph. What was wrong, missing, or slow before this PR? Lead with
*why*. If this fixes an issue, link it ("Closes #123").

## Fix

One to three paragraphs. What does this PR change to address the problem?
Describe the approach, not the line-by-line diff. The reviewer can read
the diff; they cannot read your mind about why you chose this approach
over alternatives you considered.

## Example

A minimal Grape API snippet that triggers the changed behavior. Keep it
under ~15 lines — strip everything not load-bearing for the example.

```ruby
class API < Grape::API
  # the smallest API that demonstrates the change
end
```

## Schema before / after

Show the OAS output for the example above, before and after this PR. Use
`yaml` or `json` fenced blocks. Diff comments (`# Before` / `# After`)
are encouraged. If you changed multiple call sites, show one example per
site, not all of them.

```yaml
# Before
properties:
  role:
    $ref: "#/components/schemas/UserEntity"

# After — in OAS 3.0 a $ref cannot have sibling keywords, so allOf
# is the canonical workaround for attaching attributes (default,
# enum, constraints). OAS 3.1 allows $ref siblings, but the exporter
# still emits the allOf wrap for output consistency across versions.
properties:
  role:
    allOf:
      - $ref: "#/components/schemas/UserEntity"
    default: "guest"
```

## Backward compatibility

One sentence per category:
- Public API surface: changed / unchanged?
- Emitted OAS shape for inputs that don't exercise this fix: changed /
  unchanged?
- New runtime/dev dependencies: yes (justify) / no?

If everything is unchanged, write "No public API or emitted-shape changes
for inputs not exercising this fix."

## Open questions (optional)

Things you want the reviewer's opinion on. Naming, scope of the change,
"is this the right place to put this?" Flag explicitly so the reviewer
engages with them rather than rubber-stamping.
````

## What you do *not* include

- **Test plan / "How I tested this".** The diff in `test/` and CI
  already cover what was tested; restating it is noise. A short
  *coverage* note is fine when the test diff alone doesn't make the
  scope obvious (e.g. "covers cold + warm-cache paths" for a
  caching change). The line is: don't restate, do flag what's
  non-obvious.
- **Agent attribution footers** like `🤖 Generated with [Claude Code]`
  or `Co-Authored-By: Claude`. These belong nowhere in this repo.
- **Bullet lists of every file you touched.** The diff already shows
  that.
- **Restating the diff in prose.** "I added a method called `foo` that
  does X" wastes reviewer attention if the diff is right there.

## When the schema-before-after section can't be filled

If the change provably does not affect emitted output (a pure refactor,
a documentation change, a CI tweak), say so explicitly in place of the
schema diff. "Provably" means: re-run the e2e fixtures
(`bundle exec rake test TEST=test/e2e/...`) before and after the
change and confirm byte-identical output.

```markdown
## Schema before / after

No change to emitted output. This PR refactors `<file>`; coverage is in
`test/grape_oas/<file>_test.rb`, which produces identical fixtures
before and after.
```

Don't omit the section silently — the reviewer needs to know you
considered it.

## Worked example (small bug fix)

A complete PR body constructed around the PR #78 fix to demonstrate
every required section. The actual PR #78 body uses a subset
(Problem / Fix / Test change); the version below is the
template-conforming form of the same change.

````markdown
## Problem

When a route has no entity and no documented response, grape-oas emits
`schema: { type: string }` for the response body. This is incorrect — it
tells API consumers the endpoint returns a plain string, when in
reality the response shape is simply unknown.

## Fix

An undocumented response should produce an empty schema (`{}`), which
is the correct OAS representation for "any value / shape unknown".
The OAS3 response builder now defaults to `{}` when no schema source
(entity, documented response, params) is available, instead of falling
through to the primitive resolver's default.

## Example

```ruby
class API < Grape::API
  format :json

  resource :ping do
    desc "Health check"
    get { { status: "ok" } }
  end
end
```

## Schema before / after

```yaml
# Before — incorrectly claims the response is a string
paths:
  /ping:
    get:
      responses:
        '200':
          description: Health check
          content:
            application/json:
              schema:
                type: string

# After — empty schema correctly means "any value / shape unknown"
paths:
  /ping:
    get:
      responses:
        '200':
          description: Health check
          content:
            application/json:
              schema: {}
```

## Backward compatibility

- Public API surface: unchanged.
- Emitted OAS shape for inputs that don't exercise this fix: unchanged
  — only routes with no entity and no documented response are affected.
- New runtime/dev dependencies: none.
````

## Patterns for larger PRs

When a single PR changes behavior across several rendering paths or
introduces a measured perf improvement, the template grows in two
predictable ways. Both predate this template, but the patterns are
worth lifting:

- **Multiple `## Example` blocks**, one per affected rendering path
  (e.g. `$ref` wrapper, `allOf`, `oneOf`). PR #70 ("Propagate schema
  attributes through `$ref` and composition paths") is a good example.
- **Attribute or behavior survival matrix** — a small table summarizing
  the new behavior across paths. Earns its space when the diff touches
  many independent call sites; PR #70 ships one.
- **Measured-impact table** for performance work, with before/after
  numbers and the profiling output that motivated the change. PR #64
  ("perf: memoize default_format and content_types resolution per
  generation") is the reference here.

Note: PR #70 and PR #64 predate the template entirely. They use
`## Summary` instead of `## Problem`, lack most of the required
sections, and PR #64 has a `## Tests` section that this template
discourages. Lift the listed patterns; do not lift the section names
or overall structure.

## Workflow around opening the PR

The project convention for CHANGELOG entries includes the PR number
and author handle, so the entry can only be written *after* the PR
is opened. Order of operations:

**Before opening the PR**

1. Run `bundle exec rake` (test + rubocop) locally. CI runs the same
   checks but splits them across a rubocop job and a Ruby × Grape
   test matrix.
2. Confirm the schema-before-after block in the PR body matches the
   actual diff in `test/`. If they disagree, the test wins; update
   the PR body.

**After opening the PR (and getting its number)**

1. Add a line under the appropriate subsection of `## [Unreleased]` in
   `CHANGELOG.md` (`### Added`, `### Fixed`, or `### Changed`). The
   format used throughout this project is:

   ```
   - [#N](https://github.com/numbata/grape-oas/pull/N): One-line
     user-readable summary - [@handle](https://github.com/handle).
   ```

   Keep the summary tight — one phrase describing the user-visible
   change, not the implementation. Aim for under ~120 characters of
   summary text. Skim recent entries in `CHANGELOG.md` for examples
   of the right length.

2. Push the CHANGELOG commit to the PR branch. Danger
   (`changelog.check!`) does two things: it warns when
   `CHANGELOG.md` is unmodified and fails when any line breaks
   Keep-a-Changelog format. The PR-numbered link form is one of two
   formats Danger accepts; this project conventionally uses it for
   traceability, but `* Capitalized summary - [@handle](url).` (no
   PR link) would also pass. The CHANGELOG entry lives in the file,
   not in the PR body.

## Commit messages

Same rules apply, scaled down:

- Imperative present tense ("Propagate schema attributes…", not
  "Propagated" or "Propagates").
- First line under 72 characters.
- Body explains *why* and links the issue if relevant.
- No agent attribution footers.
- One logical change per commit. One logical change per PR.
