# Upgrading grape-oas

### Upgrading to >= 1.5.0

When upgrading from 1.4.0, regenerate your OpenAPI documents and review the diff before regenerating clients.
This release corrects several schema shapes and changes how documentation routes
are mounted. See [CHANGELOG.md](CHANGELOG.md) for the full list of changes.

#### Documentation routes are mounted even when hidden

`hide_documentation_path: true` previously prevented documentation routes from
being mounted. It now mounts them and hides them from the generated specification.
It is also the new default.

If you used this option to disable documentation in an environment, conditionally
omit the DSL call instead:

```ruby
class API < Grape::API
  # Declare your API routes here.

  add_oas_documentation if ENV["ENABLE_API_DOCS"] == "true"
end
```

To include the documentation routes in the generated specification, use
`add_oas_documentation(hide_documentation_path: false)`. Hiding a route from the
specification does not restrict HTTP access to it.

#### Generic integers no longer imply a 32-bit format

Generic `Integer` and `"integer"` declarations now emit `type: integer` without
the previously inferred `format: int32`. This can change the integer type selected
by a client generator. Declare a width explicitly when your API requires it:

```ruby
params do
  requires :count, type: Integer, documentation: { format: "int32" }
end
```

For entity exposures, use
`documentation: { type: "integer", format: "int64" }` (or `"int32"`).

#### Entity exposures use the type resolver registry

Entity exposures now consult `GrapeOAS.type_resolvers`. Existing custom resolvers
can therefore affect response schemas as well as request parameters. Review their
`handles?` predicates and compare generated entity schemas after upgrading.

The registry also has migration-relevant changes:

- Replace registry calls to `handles?(type)` with
  `registered_resolver_for?(type)`; `handles?` now emits a deprecation warning.
  Custom resolver classes still implement their own `handles?` method.
- `build_schema(type)` now returns a fallback string schema when no registered
  resolver supplies a schema, including after `clear`. Do not use a `nil` result
  to detect unsupported types. `registered_resolver_for?` checks whether a
  registered resolver claims the type; it does not guarantee that the resolver
  will return a schema.
- A resolver returning `nil` from `build_schema` now lets the registry try later
  resolvers before using the fallback.
- `find` is now private. Use `registered_resolver_for?` for a membership check or
  `build_schema` to resolve a type. To inspect the first matching resolver, use
  `GrapeOAS.type_resolvers.to_a.find { |resolver| resolver.handles?(type) }`.

#### Explicit media types affect OAS2 form generation

Route `consumes:` and `produces:` declarations now override inferred media types
independently. Check existing declarations for stale values.

For OAS2 operations consuming only `application/x-www-form-urlencoded` or
`multipart/form-data`, request properties now become `formData` parameters.
Complex form fields (objects, compositions, or referenced array items) raise
`ArgumentError` during generation. Use OAS3 to describe those requests, or simplify
the form schema if that accurately reflects your API. Primitive fields, files,
and arrays of primitives remain supported.

#### Generated schemas reflect corrected types and requiredness

Review schema snapshots and generated clients for these corrections:

- **Nullability:** OAS2 emits `x-nullable: true` by default for nullable schemas.
  OAS3.1 inline parameters, request bodies, and responses now use its JSON Schema
  null representation. Nullable OAS3 references and compositions retain
  nullability, and null-union alternatives may now contain a bare `$ref` instead
  of a single-element `allOf`. Update tooling that assumes the old wrapper shape.
- **Conditional parameters:** fields declared inside Grape `given` blocks are
  optional in the generated schema unless also required unconditionally.
  Conditional fields alone no longer make the request body required. Grape still
  enforces conditions at runtime; the generated schema does not encode them.
- **Responses:** undocumented response schemas are now empty (`{}`) instead of
  `type: string`. Declare a response entity if consumers need a concrete type.
  Responses with status `1xx`, `204`, `205`, or `304` omit body schemas/content,
  including declared entities and examples. Plain-entity responses with
  `is_array: true` now correctly emit arrays.
- **Hidden entity fields:** exposures with `documentation: { hidden: true }` are
  omitted. Remove that flag if the field should remain documented.
- **Versioned paths:** path-based Grape versions now appear as concrete path
  segments instead of unresolved version parameters. Regenerate clients that
  previously accepted the version as an argument.

New `schema_ref_name` and `oas2_composition_extensions` options are opt-in and
require no configuration changes for existing applications.
