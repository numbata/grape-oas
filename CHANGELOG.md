# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- [#30](https://github.com/numbata/grape-oas/pull/30): Add support for Grape's native `contract` DSL resolution when building request schemas - [@numbata](https://github.com/numbata).
- [#28](https://github.com/numbata/grape-oas/pull/28): support nested dry-contracts query parameters with style & explode - [@slbug](https://github.com/slbug).
- [#24](https://github.com/numbata/grape-oas/pull/24): Properly parse desc blocks with responses [@slbug](https://github.com/slbug).
- [#27](https://github.com/numbata/grape-oas/pull/27): Add release workflow - [@numbata](https://github.com/numbata).
- [#26](https://github.com/numbata/grape-oas/pull/26): Add danger validation - [@numbata](https://github.com/numbata).
- [#23](https://github.com/numbata/grape-oas/pull/23): Add oneOf support for response schemas - [@slbug](https://github.com/slbug).

### Fixed

- [#33](https://github.com/numbata/grape-oas/pull/33): Improve schema generation: add format hints, optimize nullable types, fix enum handling for arrays and oneOf - [@numbata](https://github.com/numbata).
- [#31](https://github.com/numbata/grape-oas/pull/31): Fix: prefer `using:` option over `documentation: { type: "object" }` - [@numbata](https://github.com/numbata).
- [#22](https://github.com/numbata/grape-oas/pull/22): Handle boolean types in dry introspector - [@slbug](https://github.com/slbug).

## [1.0.3] - 2025-12-23

### Fixed

- [#21](https://github.com/numbata/grape-oas/pull/21): Remove unnecessary require_relative in favor of Zeitwerk autoloadin - [@numbata](https://github.com/numbata).
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
  - Global options: host, base_path, schemes, servers, consumes, produces
  - Info object: title, version, description, contact, license, terms_of_service
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
