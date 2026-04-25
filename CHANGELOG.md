# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- [#92](https://github.com/numbata/grape-oas/pull/92): Add cross-tool AI-agent contributor guidance and tighten gem file packaging - [@numbata](https://github.com/numbata).
- Your contribution here

### Fixed

- [#78](https://github.com/numbata/grape-oas/pull/78): Fix: use empty schema for undocumented responses instead of `{ type: string }` - [@bogdan](https://github.com/bogdan).
* Your contribution here

### Changed

* Your contribution here

## [1.4.0] - 2026-04-23

### Fixed

- [#60](https://github.com/numbata/grape-oas/pull/60): Fix `Dangerfile` to properly look for tests - [@olivier-thatch](https://github.com/olivier-thatch).
- [#58](https://github.com/numbata/grape-oas/pull/58): Fix contract extraction compatibility with Grape 3.2 - [@numbata](https://github.com/numbata).
- [#57](https://github.com/numbata/grape-oas/pull/57): Fix `Array<Array<...>>` double-wrap when `is_array: true` is used with typed array notation like `type: [String]` — the redundant `is_array` flag no longer produces a nested array schema - [@numbata](https://github.com/numbata).
- [#59](https://github.com/numbata/grape-oas/pull/59): Export `default` param values to OAS2 and OAS3 output - [@olivier-thatch](https://github.com/olivier-thatch).
- [#61](https://github.com/numbata/grape-oas/pull/61): Respect `entity_name` on `grape::entity` subclasses - [@olivier-thatch](https://github.com/olivier-thatch).
- [#68](https://github.com/numbata/grape-oas/pull/68): De-duplicate parameter `description` between the Parameter Object and its nested `schema` in OAS 3 output - [@olivier-thatch](https://github.com/olivier-thatch).
- [#70](https://github.com/numbata/grape-oas/pull/70): Propagate schema attributes (`default`, `enum`, constraints, extensions) through `$ref` and composition paths - [@numbata](https://github.com/numbata).
- Your contribution here

### Changed

- [#64](https://github.com/numbata/grape-oas/pull/64): Memoize content-type and default-format resolution per generation — eliminates redundant calls that scaled with route × response count - [@JuniorJoanis](https://github.com/JuniorJoanis).
- [#62](https://github.com/numbata/grape-oas/pull/62): Default to body params for post/put/patch routes - [@olivier-thatch](https://github.com/olivier-thatch).

## [1.3.0] - 2026-03-27

### Added

- [#48](https://github.com/numbata/grape-oas/pull/48): Add configurable `GrapeOAS.logger` for schema generation warnings - [@numbata](https://github.com/numbata).
- [#43](https://github.com/numbata/grape-oas/pull/43): Bump actions/upload-artifact from 6 to 7 - [@dependabot[bot]](https://github.com/dependabot[bot]).
- [#51](https://github.com/numbata/grape-oas/pull/51): Add inline nesting exposure support — block-based `expose :key do ... end` now produces inline object schemas with preserved enum values, min/max constraints, and metadata - [@numbata](https://github.com/numbata).

### Changed

- [#52](https://github.com/numbata/grape-oas/pull/52): Extract `SchemaConstraints` — centralizes numeric/string constraint application (min/max, exclusive flags, length, pattern) and adds `exclusive_minimum`/`exclusive_maximum` support - [@numbata](https://github.com/numbata).
- [#50](https://github.com/numbata/grape-oas/pull/50): Extract `ValuesNormalizer` — consolidates Proc/Set/Hash value normalization into a single module used by both request params and entity exposures - [@numbata](https://github.com/numbata).

### Fixed

- [#55](https://github.com/numbata/grape-oas/pull/55): Preserve enum values on cached entity schemas — dup the shared schema before applying enum instead of silently discarding the constraint; emit a warning naming the entity - [@numbata](https://github.com/numbata).
- [#56](https://github.com/numbata/grape-oas/pull/56): Make `NestingMerger` depth-cap warning actionable — include property name and depth cap value in the message - [@numbata](https://github.com/numbata).
- [#50](https://github.com/numbata/grape-oas/pull/50): Fix `[false]` enum silently dropped — `[false].any?` returns `false` in Ruby, causing boolean-only enum constraints to be discarded - [@numbata](https://github.com/numbata).

- [#49](https://github.com/numbata/grape-oas/pull/49): Fix OOM on wide string range expansion in `values:` — replace unbounded `range.to_a` with bounded enumeration; non-numeric ranges on numeric schemas and numeric ranges on non-numeric schemas now warn and are ignored instead of silently producing invalid output - [@numbata](https://github.com/numbata).
- [#46](https://github.com/numbata/grape-oas/pull/46): Fix `is_array: true` in request param documentation being ignored for primitive types — only entity types were wrapped in array schema - [@numbata](https://github.com/numbata).
- [#42](https://github.com/numbata/grape-oas/pull/42): Fix array items `description` and `nullable` placement — hoist to outer array schema instead of wrapping `items` in `allOf`; fix `:description` field naming collision in `PropertyExtractor` - [@numbata](https://github.com/numbata).
- [#44](https://github.com/numbata/grape-oas/pull/44): Fix RuboCop 1.85 offenses - [@numbata](https://github.com/numbata).
- [#47](https://github.com/numbata/grape-oas/pull/47): Fix duplicate entries in `Schema#required` array when the same property is added multiple times with `required: true` - [@numbata](https://github.com/numbata).

## [1.2.0] - 2026-03-02

### Added

- [#36](https://github.com/numbata/grape-oas/pull/36): Add extensible TypeResolvers for resolving Grape's stringified parameter types to OpenAPI schemas with rich metadata (format, enum, nullable) - [@numbata](https://github.com/numbata).
- [#37](https://github.com/numbata/grape-oas/pull/37): Replace boolean `nullable_keyword` with configurable `nullable_strategy` - [@numbata](https://github.com/numbata).

### Fixed

- [#41](https://github.com/numbata/grape-oas/pull/41): Fix `Set` enum values being silently dropped and `maybe(Coercible::Integer)` resolving to `string` instead of `integer` - [@numbata](https://github.com/numbata).
- [#40](https://github.com/numbata/grape-oas/pull/40): Remove dead `spec[:allow_nil]` and `spec[:nullable]` checks from `extract_nullable` — these values were never set by Grape or grape-swagger - [@numbata](https://github.com/numbata).
- [#39](https://github.com/numbata/grape-oas/pull/39): Support `documentation: { x: { nullable: true } }` on nested Hash params — nullable flag was ignored for object container schemas - [@numbata](https://github.com/numbata).
- [#38](https://github.com/numbata/grape-oas/pull/38): Wrap `$ref` in `allOf` when `description` or `nullable` is present — fixes sibling properties being ignored per OpenAPI spec - [@numbata](https://github.com/numbata).
- [#37](https://github.com/numbata/grape-oas/pull/37): Fix OAS 3.0 `nullable` keyword being constructed but not emitted in the generated output - [@numbata](https://github.com/numbata).

## [1.1.0] - 2026-01-23

### Added

- [#30](https://github.com/numbata/grape-oas/pull/30): Add support for Grape's native `contract` DSL resolution when building request schemas - [@numbata](https://github.com/numbata).
- [#28](https://github.com/numbata/grape-oas/pull/28): support nested dry-contracts query parameters with style & explode - [@slbug](https://github.com/slbug).
- [#24](https://github.com/numbata/grape-oas/pull/24): Properly parse desc blocks with responses [@slbug](https://github.com/slbug).
- [#27](https://github.com/numbata/grape-oas/pull/27): Add release workflow - [@numbata](https://github.com/numbata).
- [#26](https://github.com/numbata/grape-oas/pull/26): Add danger validation - [@numbata](https://github.com/numbata).
- [#23](https://github.com/numbata/grape-oas/pull/23): Add oneOf support for response schemas - [@slbug](https://github.com/slbug).

### Fixed

- [#33](https://github.com/numbata/grape-oas/pull/33): Improve schema generation: add format hints, optimize nullable types, fix enum handling for arrays and oneOf - [@numbata](https://github.com/numbata).
- [#34](https://github.com/numbata/grape-oas/pull/34): Convert numeric `included_in?` ranges to min/max constraints instead of enum - [@numbata](https://github.com/numbata).
- [#31](https://github.com/numbata/grape-oas/pull/31): Fix: prefer `using:` option over `documentation: { type: "object" }` - [@numbata](https://github.com/numbata).
- [#22](https://github.com/numbata/grape-oas/pull/22): Handle boolean types in dry introspector - [@slbug](https://github.com/slbug).

## [1.0.3] - 2025-12-23

### Fixed

- [#21](https://github.com/numbata/grape-oas/pull/21): Remove unnecessary require\_relative in favor of Zeitwerk autoloadin - [@numbata](https://github.com/numbata).
- [#17](https://github.com/numbata/grape-oas/pull/17): Support for nested rules and predicates in dry-schema introspection - [@slbug](https://github.com/slbug).
- [#20](https://github.com/numbata/grape-oas/pull/20): Use annotation for coverage report - [@numbata](https://github.com/numbata).
- [#18](https://github.com/numbata/grape-oas/pull/18): Support for range in size? predicate `required(:tags).value(:array, size?: 1..10).each(:string)` - [@slbug](https://github.com/slbug).
- [#19](https://github.com/numbata/grape-oas/pull/19): Temporary disable memory profiler workflow for PRs - [@numbata](https://github.com/numbata).

## [1.0.2] - 2025-12-15

### Fixed

- [#14](https://github.com/numbata/grape-oas/pull/14): Fix Response and ParamSchemaBuilder to use introspector registry instead of directly instantiating EntityIntrospector - [@numbata](https://github.com/numbata).

## [1.0.1] - 2025-12-15

### Fixed

- [#8](https://github.com/numbata/grape-oas/pull/8): Add OAS2 parameter schema constraint export with enum normalization and retain zero-valued constraints across OAS exporters - [@numbata](https://github.com/numbata).
- [#9](https://github.com/numbata/grape-oas/pull/9): Treat GET/HEAD/DELETE as bodyless by default via shared constants and tests - [@numbata](https://github.com/numbata).
- [#10](https://github.com/numbata/grape-oas/pull/10): Add grape-swagger compatible `in:` location syntax for parameters alongside `param_type` - [@numbata](https://github.com/numbata).
- [#11](https://github.com/numbata/grape-oas/pull/11): Flatten nested Hash params to bracket-notation query params for GET/HEAD/DELETE requests - [@numbata](https://github.com/numbata).
- [#12](https://github.com/numbata/grape-oas/pull/12): Add fallback to `spec[:desc]` for parameter descriptions when `documentation[:desc]` is not set - [@numbata](https://github.com/numbata).

## [1.0.0] - 2025-12-06

### Added

- Core Features
  - OpenAPI specification generation for Grape APIs
  - Support for OpenAPI 2.0 (Swagger), 3.0, and 3.1 specifications
  - `GrapeOAS.generate(app:, schema_type:)` for programmatic generation
  - `add_oas_documentation` DSL for mounting documentation endpoint
  - `add_swagger_documentation` compatibility shim for grape-swagger migration
  - Query parameter `?oas=2|3|3.1` for version selection at runtime
-  Entity Support
  - Built-in Grape::Entity introspection (no separate gem needed)
  - Dry::Validation::Contract and Dry::Struct support
  - Entity inheritance with `allOf` composition
  - Polymorphism support with `discriminator`
  - Sum types (`|`) converted to `anyOf`
  - Circular reference handling with `$ref`
-  Parameter Documentation
  - All Grape parameter types (String, Integer, Float, Boolean, Date, DateTime, Array, Hash, File)
  - Nested parameters (Hash with block)
  - Array parameters with item types (`Array[String]`, `Array[Integer]`)
  - Multi-type parameters (`types: [String, Integer]`)
  - Parameter validation constraints (values, regexp, minimum, maximum, etc.)
  - Parameter hiding (`documentation: { hidden: true }`)
  - `collectionFormat` support for OAS2 arrays
-  Response Documentation
  - `success` and `failure` response definitions
  - Multiple success/failure status codes
  - Response headers
  - Response examples
  - Multiple present responses with `as:` key combination
  - Root element wrapping support
  - `suppress_default_error_response` option
-  Endpoint Documentation
  - `desc` block syntax with detail, tags, deprecated, consumes, produces
  - Endpoint hiding (`hidden: true` or lambda)
  - `body_name` for custom body parameter naming (OAS2)
  - Request body for GET/HEAD/DELETE when explicitly enabled
  - Operation extensions (`x-*` properties)
-  Configuration
  - Global options: host, base\_path, schemes, servers, consumes, produces
  - Info object: title, version, description, contact, license, terms\_of\_service
  - Security definitions (API key, OAuth2, Bearer)
  - Tag definitions with descriptions
  - `models` option to pre-register entities
  - Namespace filtering for partial schema generation
  - URL-based namespace filtering for mounted docs (`/swagger_doc/users`)
  - Tag filtering to only include used tags
-  Rake Tasks
  - `grape_oas:generate[API,schema_type,output_path]` for file generation
  - `grape_oas:validate[file_path]` for spec validation
- Migration Support
  - Comprehensive migration guide from grape-swagger
  - Feature parity documentation
  - Compatibility shim for `add_swagger_documentation`
-  Extensibility
  - Introspector registry - register custom introspectors via `GrapeOAS.introspectors.register()`
  - Exporter registry - register custom exporters via `GrapeOAS.exporters.register(ExporterClass, as: :alias)`
- Documentation
  - README with full usage examples
  - `docs/MIGRATING_FROM_GRAPE_SWAGGER.md` - detailed migration guide
  - `docs/ARCHITECTURE.md` - system architecture overview
  - `docs/INTROSPECTORS.md` - introspector system documentation
  - `docs/EXPORTERS.md` - exporter system documentation
  - `docs/API_MODEL.md` - internal API model reference
