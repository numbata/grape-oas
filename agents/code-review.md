# Reviewing a grape-oas change

Apply this when reviewing your own work before opening a PR, reviewing
someone else's PR, or running `/critique` on a working tree.

## Mindset

Adversarial toward the code, not the author. Assume the diff is wrong
until proven right. Every line earns its place. Your job is to catch
things the author missed.

Skip encouragement padding ("great refactor", "nice catch"). Skip
sneering ("obviously", "surprised this passed CI"). State the problem
and the fix; the harshness is in the standard, not the tone.

## What to check, in order

Work through all six in order before reporting; partial reviews waste
the author's cycles. (See "What NOT to do" for why.)

### 1. Schema correctness

This is the highest-stakes axis in this repo. Mistakes here ship broken
OpenAPI to every consumer of every API that uses grape-oas.

- Does the emitted OAS still validate against the spec for every path
  the diff touches? OAS 3.0 and 3.1 have different rules — check both
  if both exporters are affected.
- For OAS 3.0 changes: is the `nullable` representation correct for
  the API's `nullable_strategy:`? OAS 3.0 honors the option, so both
  `nullable: true` (`KEYWORD`) and `type: ["X", "null"]`
  (`TYPE_ARRAY`) can be legitimate output — check the API's strategy
  before flagging either as a bug.
- For OAS 3.1 changes: output must always be `type: ["X", "null"]`.
  OAS 3.1 hard-overrides `nullable_strategy` to `TYPE_ARRAY`
  regardless of the API option (see
  `lib/grape_oas/exporter/oas31_schema.rb`). A `nullable: true` in
  3.1 output is a bug, full stop.
- For OAS 2.0 changes: nullable handling is currently underspecified
  in the codebase (no default strategy, no fallback in the
  exporter — see issue #91). Do not block on nullable representation
  in OAS 2.0 output unless the change clearly regresses behavior;
  flag uncertainty for maintainer review.
- Are keys in emitted output **strings**, never symbols?
- Are optional keys **omitted** when their value would be nil/empty,
  rather than emitted with a `null` value?
- Do `$ref` and composition (`allOf` / `oneOf` / `anyOf`) paths
  preserve the attributes the author thinks they preserve? `$ref`
  wrappers in particular drop most attributes unless the author
  explicitly handled them. PR #70's attribute survival matrix is the
  reference.

### 2. Test coverage of the actual change

- Is there a test that **fails on the parent commit and passes on this
  commit**? If not, the test does not prove the fix works. Ask for a
  regression test.
- Bug fix without a regression test → block.
- New public method without a test → block.
- Did the author update an existing test that asserted the buggy
  behavior? If so, the test name and surrounding comments should
  reflect the *new* intended behavior, not the old one.
- Are end-to-end tests in `test/e2e/` being added when a unit test in
  `test/grape_oas/` would suffice? E2E tests are slow — push back.

### 3. Boundary violations

- Does the diff monkey-patch any Grape class from `lib/`? Should be an
  explicit extension module instead.
- Does it touch `.github/workflows/`, `Dangerfile`, `Rakefile`, or
  release tasks without flagging it as a process change in the PR
  body?
- Does it add a runtime dependency to `grape-oas.gemspec` without
  justification in the PR body?
- Does it add code under `lib/grape_oas/` that's clearly not part of
  any existing namespace (`introspectors/`, `exporter/`,
  `type_resolvers/`, `api_model/`, `api_model_builders/`)? Where does
  it belong?

### 4. Backward compatibility

- Does the public API surface change? `GrapeOAS.<method>` signatures,
  any class documented in `docs/`, anything users call directly.
- Does the emitted OAS shape change for **inputs that don't exercise
  the fix**? That is the silent breakage that hurts most. Look for
  changed defaults, removed keys, reordered output.
- If either is true, is it called out in the PR body's
  backward-compatibility section? If not → block.

### 5. CHANGELOG and PR body

- Is there a new entry under `## [Unreleased]` in `CHANGELOG.md`?
  Danger checks file modification and line format, not specifically
  `## [Unreleased]` presence — verify visually.
- Does the PR body have the required sections (Problem / Fix / Example
  / Schema before-after / Backward compatibility)? See
  [pr-description.md](pr-description.md).
- Is the schema-before-after block actually showing the change, or is
  it a copy-paste of identical YAML?

### 6. Code quality (the easy stuff)

This last because RuboCop catches most of it.

- File size: any new/modified file pushing past ~400 lines? If so,
  what would split cleanly out? See [conventions.md](conventions.md).
- Comments: any "explains what the next line does" slop? Any "added
  for X" / "used by Y" / "fix for issue #123" rot? Any TODO without an
  owner or issue link? Strip them.
- Method length: RuboCop caps methods at 60 lines, but anything past
  30 is worth questioning unless the method is genuinely sequential
  setup.
- Naming: does each new identifier carry its weight? `data`, `result`,
  `obj`, `value` are usually a sign the author didn't think hard
  enough.

## How to write the review

Order findings from "this blocks the PR" to "this is a nit". Use these
labels:

- **Block:** must be fixed before merge. Schema-correctness bugs,
  missing regression tests, broken backward compatibility without
  callout, missing CHANGELOG entry.
- **Should fix:** should be fixed before merge but author can push
  back. Naming, splitting a long method, missing edge-case test.
- **Consider:** worth thinking about, author's call. Refactoring
  suggestions, alternative approaches, future-proofing.
- **Nit:** style, formatting, comment phrasing. Mention once, do not
  block.

For each finding, give:

1. The location (`file:line` if you can).
2. What's wrong.
3. The fix, or a concrete question if the fix isn't obvious.

Example finding:

```
**Block** — `lib/grape_oas/exporter/oas3_schema.rb:142`

`build_one_of_schema` doesn't propagate `default` to the composition
wrapper. The fix in this PR works for `allOf` and `anyOf` but the
`oneOf` path silently drops it. Add the same `default: schema.default
if schema.default` line and a test in
`test/grape_oas/exporter/oas3_schema_test.rb`.
```

## What NOT to do

- Do not invent issues that aren't in the diff. If you can't point to
  a line, the finding doesn't exist.
- Do not score the PR (no "7/10", no letter grades). The findings list
  is the verdict.
- Do not include encouragement padding. No "great catch on the
  constraint bug, by the way".
- Do not insult the author or the prior code. Even if the prior code
  was bad, "this was broken because…" is fine; "whoever wrote this
  clearly didn't…" is not.
- Do not stop at the first problem. Run all six checks every time —
  partial reviews waste review cycles.

## When you have nothing to say

If the diff is genuinely good, the entire review is:

> Reviewed against the grape-oas review checklist. Schema correctness,
> test coverage, boundaries, backward compatibility, CHANGELOG, and
> code quality all check out. No findings.

Resist the urge to invent something to look thorough.
