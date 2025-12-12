# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Fixes

- [#8](https://github.com/numbata/grape-oas/pull/8): Add OAS2 parameter schema constraint export with enum normalization and retain zero-valued constraints across OAS exporters. - [@numbata](https://github.com/numbata).
- [#9](https://github.com/numbata/grape-oas/pull/9): Treat GET/HEAD/DELETE as bodyless by default via shared constants and tests - [@numbata](https://github.com/numbata).

## [1.0.0] - 2025-12-06

### Added

#### Core Features
- OpenAPI specification generation for Grape APIs
- Support for OpenAPI 2.0 (Swagger), 3.0, and 3.1 specifications
- `GrapeOAS.generate(app:, schema_type:)` for programmatic generation
- `add_oas_documentation` DSL for mounting documentation endpoint
- `add_swagger_documentation` compatibility shim for grape-swagger migration
- Query parameter `?oas=2|3|3.1` for version selection at runtime

#### Entity Support
- Built-in Grape::Entity introspection (no separate gem needed)
- Dry::Validation::Contract and Dry::Struct support
- Entity inheritance with `allOf` composition
- Polymorphism support with `discriminator`
- Sum types (`|`) converted to `anyOf`
- Circular reference handling with `$ref`

#### Parameter Documentation
- All Grape parameter types (String, Integer, Float, Boolean, Date, DateTime, Array, Hash, File)
- Nested parameters (Hash with block)
- Array parameters with item types (`Array[String]`, `Array[Integer]`)
- Multi-type parameters (`types: [String, Integer]`)
- Parameter validation constraints (values, regexp, minimum, maximum, etc.)
- Parameter hiding (`documentation: { hidden: true }`)
- `collectionFormat` support for OAS2 arrays

#### Response Documentation
- `success` and `failure` response definitions
- Multiple success/failure status codes
- Response headers
- Response examples
- Multiple present responses with `as:` key combination
- Root element wrapping support
- `suppress_default_error_response` option

#### Endpoint Documentation
- `desc` block syntax with detail, tags, deprecated, consumes, produces
- Endpoint hiding (`hidden: true` or lambda)
- `body_name` for custom body parameter naming (OAS2)
- Request body for GET/HEAD/DELETE when explicitly enabled
- Operation extensions (`x-*` properties)

#### Configuration
- Global options: host, base_path, schemes, servers, consumes, produces
- Info object: title, version, description, contact, license, terms_of_service
- Security definitions (API key, OAuth2, Bearer)
- Tag definitions with descriptions
- `models` option to pre-register entities
- Namespace filtering for partial schema generation
- URL-based namespace filtering for mounted docs (`/swagger_doc/users`)
- Tag filtering to only include used tags

#### Rake Tasks
- `grape_oas:generate[API,schema_type,output_path]` for file generation
- `grape_oas:validate[file_path]` for spec validation

#### Migration Support
- Comprehensive migration guide from grape-swagger
- Feature parity documentation
- Compatibility shim for `add_swagger_documentation`

#### Extensibility
- Introspector registry - register custom introspectors via `GrapeOAS.introspectors.register()`
- Exporter registry - register custom exporters via `GrapeOAS.exporters.register(ExporterClass, as: :alias)`

### Documentation
- README with full usage examples
- `docs/MIGRATING_FROM_GRAPE_SWAGGER.md` - detailed migration guide
- `docs/ARCHITECTURE.md` - system architecture overview
- `docs/INTROSPECTORS.md` - introspector system documentation
- `docs/EXPORTERS.md` - exporter system documentation
- `docs/API_MODEL.md` - internal API model reference
