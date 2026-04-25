# grape-oas conventions

Conventions that aren't enforced by RuboCop. Read this before adding new
code. RuboCop is the source of truth for whitespace, string quotes, line
length, and similar mechanical rules — this file covers everything else.

## File size

There is no hard cap. RuboCop's `Metrics/ClassLength` is disabled
deliberately — some classes (`exporter/oas3_schema.rb`, the
introspectors) are inherently large because they sit on top of a wide
upstream surface.

The soft rule: **if a file is doing more than one thing, split it.**
`lib/grape_oas/introspectors/dry_introspector_support/` is the model —
one file per responsibility (argument extraction, AST walking, type
unwrapping, constraint extraction / merging / application, predicate
handling, contract resolution, inheritance, rule indexing, type-schema
building) instead of one giant introspector. When the introspector
itself was getting unwieldy, the shared helpers were extracted; the
entry point stayed small.

Heuristic for a new file: if you can't write a one-sentence description
of what it does without using the word "and", it's too big. Split before
merging, not after.

## Method length

RuboCop allows up to 60 lines per method. Most methods should be much
shorter. Anything past ~30 lines is worth asking "what subroutine is
hiding in here?". The metrics-cop exemptions in `.rubocop.yml` for the
dry introspectors (`Metrics/MethodLength`, `Metrics/AbcSize`,
`Metrics/CyclomaticComplexity`, `Metrics/PerceivedComplexity`) exist
because dry-types' AST shape forces a wide dispatch — those are
exceptions, not patterns to copy.

## Comments

Default to writing **no comments**. Add one only when the *why* is
non-obvious — a hidden upstream Grape constraint, a workaround for an
OAS spec quirk, a non-obvious invariant.

Do not comment:

- What the code does (well-named identifiers cover that).
- The current task or fix (`# added for the entity-array fix` —
  belongs in the PR description, rots in code).
- Who calls this method (`# called from OAS3::Schema#build` — call
  sites move).
- Removed code (no `# removed: foo_bar()` placeholders).
- TODOs without an owner or linked issue.

Rule of thumb: if the comment would still be true a year from now,
keep it; if it describes this week's state, delete it.

## Naming

- Classes named after the thing they represent in the OAS spec when
  applicable: `Operation`, `Response`, `Parameter`, `Schema`. Don't
  invent internal names that diverge from the spec vocabulary.
- Internal helpers go under a `*_support/` directory next to the
  consumer (see the `dry_introspector_support/` pattern).
- Avoid `data`, `result`, `obj`, `value`, `info`, `metadata` as
  variable names unless the scope is genuinely about a generic blob.
  Specificity helps readers.
- Predicate methods end in `?`. Bang methods only for genuine in-place
  mutation or for "this can raise" variants.

## Where new code goes

| Adding… | Goes under |
|---|---|
| A new way to read schemas off a Ruby type (e.g., a new ORM) | `lib/grape_oas/introspectors/` |
| A new OAS output format / version | `lib/grape_oas/exporter/` |
| A type → OAS-type mapping | `lib/grape_oas/type_resolvers/` |
| A new field on the in-memory model | `lib/grape_oas/api_model/` |
| Logic that builds the model from a Grape app | `lib/grape_oas/api_model_builders/` |
| A user-facing Rake task | `lib/grape_oas/rake/` |
| A test fixture Grape API | `test/support/` (reuse before adding) |

If your change doesn't fit any of these slots, pause. Either the slot is
missing (open an issue first), or the change belongs somewhere else.

## Public vs internal

Public surface = anything reachable from `GrapeOAS.<method>`, the
`Grape::API`-mounted DSL (`add_oas_documentation`), plus classes
documented in `docs/`. That is what semver protects.

Everything else is internal — refactor freely. If you're not sure
whether a class is part of the public surface, grep `docs/` for its
name; if it appears, treat it as public.

## Frozen string literals

Every `.rb` file starts with `# frozen_string_literal: true`. RuboCop
enforces this — but if you're creating a new file, set it from the start
rather than waiting for the linter to flag it.

## Generated output rules

Recap of the rules that affect every emitter:

- Keys are strings (per OAS spec), never symbols.
- Optional keys are *omitted* when empty, not emitted as `null`.
- Order matters for human-readable diffs but not for the spec — prefer
  insertion order that mirrors the OAS spec section order.
- Do not emit OAS extension keys (`x-*`) unless the user opted in via
  the documentation extension.
