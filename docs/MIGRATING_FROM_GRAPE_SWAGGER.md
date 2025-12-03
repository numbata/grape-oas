# Migrating from grape-swagger to grape-oas

This guide helps you migrate from [grape-swagger](https://github.com/ruby-grape/grape-swagger) to grape-oas. It covers the key differences, configuration changes, and feature parity between the two gems.

## Table of Contents

- [Overview](#overview)
- [Key Differences](#key-differences)
- [Quick Start Migration](#quick-start-migration)
- [Configuration Options](#configuration-options)
- [Endpoint Documentation](#endpoint-documentation)
- [Parameter Documentation](#parameter-documentation)
- [Response Documentation](#response-documentation)
- [Entity Support](#entity-support)
- [Security Definitions](#security-definitions)
- [Extensions](#extensions)
- [Feature Parity](#feature-parity)
- [Features Not Yet Supported](#features-not-yet-supported)
- [New Features in grape-oas](#new-features-in-grape-oas)

---

## Overview

### What's Different?

| Aspect | grape-swagger | grape-oas |
|--------|---------------|-----------|
| **OpenAPI versions** | 2.0 only | 2.0, 3.0, and 3.1 |
| **Entity support** | Requires grape-swagger-entity gem | Built-in support |
| **Contract support** | Limited | Full dry-struct/dry-types support |
| **Model parsers** | Plugin system (grape-swagger-entity, grape-swagger-representable) | Built-in introspection |
| **Documentation serving** | Mounts endpoint that serves docs | Mounts endpoint OR programmatic generation |
| **Dependencies** | grape, grape-swagger-entity (optional) | grape, zeitwerk |

### Why Migrate?

1. **OpenAPI 3.x Support**: grape-swagger only generates OpenAPI 2.0 (Swagger). grape-oas supports 2.0, 3.0, and 3.1.
2. **Simpler Setup**: No need for separate grape-swagger-entity gem.
3. **Better dry-types Support**: First-class support for dry-struct contracts.
4. **Modern Ruby**: Designed for Ruby 3.1+ with Zeitwerk autoloading.
5. **Programmatic Generation**: Generate specs without mounting an endpoint.

---

## Quick Start Migration

### Before (grape-swagger)

```ruby
# Gemfile
gem 'grape-swagger'
gem 'grape-swagger-entity'

# API
require 'grape-swagger'

class API < Grape::API
  format :json

  mount UsersAPI
  mount PostsAPI

  add_swagger_documentation(
    host: 'api.example.com',
    base_path: '/v1',
    info: {
      title: 'My API',
      version: '1.0'
    }
  )
end
```

### After (grape-oas)

```ruby
# Gemfile
gem 'grape-oas'

# API (no require needed - Zeitwerk handles it)
class API < Grape::API
  format :json

  mount UsersAPI
  mount PostsAPI

  add_oas_documentation(
    host: 'api.example.com',
    base_path: '/v1',
    info: {
      title: 'My API',
      version: '1.0'
    }
  )
end
```

### Compatibility Shim

grape-oas provides `add_swagger_documentation` as an alias when grape-swagger is not loaded:

```ruby
# This works with grape-oas (defaults to OAS 2.0 output)
add_swagger_documentation(
  host: 'api.example.com'
)
```

---

## Configuration Options

### Fully Supported Options

These options work identically in both gems:

| Option | Description |
|--------|-------------|
| `host` | API host (string or proc/lambda) |
| `base_path` | Base path (string or proc/lambda) |
| `info` | Info object (title, version, description, contact, license) |
| `security_definitions` | Security scheme definitions |
| `security` | Global security requirements |
| `tags` | Tag definitions |
| `consumes` | Global consumes MIME types |
| `produces` | Global produces MIME types |
| `models` | Pre-register entity classes |
| `hide_documentation_path` | Hide the docs endpoint from output |

### Changed Options

| grape-swagger | grape-oas | Notes |
|---------------|-----------|-------|
| `mount_path` | `oas_mount_path` | Both work, `oas_mount_path` preferred |
| `doc_version` | `oas_doc_version` | Sets default OAS version (`:oas2`, `:oas3`, `:oas31`) |

### Options Not Applicable

These grape-swagger options don't apply to grape-oas:

| Option | Reason |
|--------|--------|
| `endpoint_auth_wrapper` | grape-oas doesn't integrate with OAuth middleware |
| `swagger_endpoint_guard` | grape-oas doesn't integrate with OAuth middleware |
| `token_owner` | grape-oas doesn't integrate with OAuth middleware |
| `add_base_path` | OAS 3.x uses servers instead |
| `add_root` | Not implemented |
| `add_version` | Version is part of path in Grape |
| `array_use_braces` | Not implemented |
| `api_documentation` | Customize via standard Grape desc |
| `specific_api_documentation` | Not applicable |

### New Options in grape-oas

| Option | Description |
|--------|-------------|
| `oas_mount_path_v2` | Separate mount path for OAS 2.0 |
| `oas_mount_path_v3` | Separate mount path for OAS 3.x |
| `servers` | OAS 3.x servers array |
| `cache_control` | Set Cache-Control header on docs endpoint |
| `etag` | Set ETag header on docs endpoint |

---

## Endpoint Documentation

### Basic Description

Both gems use the same Grape DSL:

```ruby
# Works in both
desc 'Get a user by ID'
get ':id' do
  # ...
end

# Block syntax - works in both
desc 'Create a user' do
  detail 'Creates a new user with the provided attributes'
  tags ['users']
end
post do
  # ...
end
```

### Description Options

| Option | grape-swagger | grape-oas | Notes |
|--------|---------------|-----------|-------|
| `hidden` | ✅ | ✅ | Hide endpoint from docs |
| `hidden` (lambda) | ✅ | ✅ | Conditional hiding |
| `nickname` | ✅ | ❌ | Use auto-generated operationId |
| `detail` | ✅ | ✅ | Extended description |
| `summary` | ✅ | ✅ | Override summary |
| `tags` | ✅ | ✅ | Override tags |
| `deprecated` | ✅ | ✅ | Mark as deprecated |
| `is_array` | ✅ | ✅ | Response is array |
| `success` | ✅ | ✅ | Success response model |
| `failure` | ✅ | ✅ | Failure responses |
| `consumes` | ✅ | ✅ | Operation consumes |
| `produces` | ✅ | ✅ | Operation produces |
| `body_name` | ✅ | ✅ | Override body parameter name (OAS 2.0 only) |

### Body Parameter Name (OAS 2.0)

```ruby
# Works in both - customize the body parameter name
desc 'Create order', body_name: 'order_payload'
params do
  requires :item, type: String
  requires :quantity, type: Integer
end
post do; end
```

**Note:** In OAS 3.x, request bodies don't have names, so `body_name` only affects OAS 2.0 output.

### Hiding Endpoints

```ruby
# All these work in both gems

# Via desc option
desc 'Hidden endpoint', hidden: true
get :internal do; end

# Via verb option
get :internal, hidden: true do; end

# Via route_setting
route_setting :swagger, hidden: true
get :internal do; end

# Conditional (lambda)
desc 'Admin only', hidden: -> { !admin? }
get :admin do; end
```

---

## Parameter Documentation

### Basic Parameters

```ruby
# Works identically in both gems
params do
  requires :id, type: Integer, desc: 'User ID'
  optional :name, type: String, desc: 'User name'
  optional :role, type: String, values: ['admin', 'user'], default: 'user'
end
```

### Documentation Hash

```ruby
params do
  # Common options - work in both
  requires :email, type: String, documentation: {
    desc: 'Email address',
    example: 'user@example.com',
    param_type: 'query'
  }

  # grape-oas specific
  optional :data, type: Hash, documentation: {
    nullable: true,                    # OAS 3.1: type: [..., 'null']
    additional_properties: true,       # Allow extra properties
    minimum: 0,                        # Numeric constraint
    maximum: 100                       # Numeric constraint
  }
end
```

### Parameter Documentation Options

| Option | grape-swagger | grape-oas | Notes |
|--------|---------------|-----------|-------|
| `desc` | ✅ | ✅ | Parameter description |
| `type` | ✅ | ✅ | Override type |
| `param_type` | ✅ | ✅ | query, path, header, body, formData |
| `example` | ✅ | ✅ | Example value |
| `default` | ✅ | ✅ | Default value |
| `hidden` | ✅ | ✅ | Hide from docs |
| `hidden` (lambda) | ✅ | ✅ | Conditional hiding |
| `collectionFormat` | ✅ | ✅ | Array format (csv, ssv, multi) |
| `additional_properties` | ✅ | ✅ | For Hash types |
| `x` (extensions) | ✅ | ✅ | x-* extensions |
| `nullable` | ❌ | ✅ | OAS 3.1 nullable |
| `minimum` | ❌ | ✅ | Numeric minimum |
| `maximum` | ❌ | ✅ | Numeric maximum |
| `minLength` | ❌ | ✅ | String min length |
| `maxLength` | ❌ | ✅ | String max length |

### Array Parameters

```ruby
# Both gems
params do
  requires :ids, type: Array[Integer]
  optional :tags, type: Array[String], documentation: { collectionFormat: 'multi' }
end
```

### Nested Parameters

```ruby
# Both gems
params do
  requires :user, type: Hash do
    requires :name, type: String
    requires :email, type: String
    optional :address, type: Hash do
      requires :street, type: String
      requires :city, type: String
    end
  end
end
```

---

## Response Documentation

### Success Responses

```ruby
# grape-swagger style - works in both
desc 'Get user', success: Entities::User
get ':id' do; end

# Block syntax - works in both
desc 'Get user' do
  success Entities::User
end
get ':id' do; end

# With status code
desc 'Create user' do
  success code: 201, model: Entities::User, message: 'Created'
end
post do; end

# Multiple success codes
desc 'Create or update' do
  success [
    { code: 200, model: Entities::User, message: 'Updated' },
    { code: 201, model: Entities::User, message: 'Created' }
  ]
end
put ':id' do; end
```

### Failure Responses

```ruby
# Array of arrays - works in both
desc 'Get user' do
  failure [[400, 'Bad Request'], [404, 'Not Found']]
end

# With models
desc 'Get user' do
  failure [
    [400, 'Bad Request', Entities::Error],
    [404, 'Not Found', Entities::Error]
  ]
end

# Hash syntax
desc 'Get user' do
  failure [
    { code: 400, message: 'Bad Request', model: Entities::Error },
    { code: 404, message: 'Not Found', model: Entities::Error }
  ]
end
```

### Response Options

| Option | grape-swagger | grape-oas | Notes |
|--------|---------------|-----------|-------|
| `success` (entity) | ✅ | ✅ | Success response model |
| `success` (array) | ✅ | ✅ | Multiple success responses |
| `failure` | ✅ | ✅ | Failure responses |
| `default` | ✅ | ✅ | Default response |
| `is_array` | ✅ | ✅ | Response is array |
| `headers` | ✅ | ✅ | Response headers |
| `examples` | ✅ | ✅ | Response examples |
| `as` (key name) | ✅ | ✅ | Multiple present responses |
| `root` | ✅ | ❌ | Root element wrapping |

### Response Headers

```ruby
# Works in both
desc 'Create user' do
  success Entities::User, headers: {
    'X-Request-Id' => { description: 'Request ID', type: 'string' },
    'Location' => { description: 'Resource URL', type: 'string' }
  }
end
```

### Response Examples

```ruby
# Works in both
desc 'Get user' do
  success model: Entities::User, examples: {
    'application/json' => { id: 1, name: 'John' }
  }
end
```

### Default Error Response

grape-oas automatically adds a 400 response for endpoints with validations. To disable:

```ruby
# grape-oas specific
desc 'Get user', documentation: { suppress_default_error_response: true }
get ':id' do; end

# Or via route option
get ':id', suppress_default_error_response: true do; end
```

---

## Entity Support

### Grape::Entity

Both gems support grape-entity, but grape-oas has built-in support (no extra gem needed):

```ruby
# Works in both
class Entities::User < Grape::Entity
  expose :id, documentation: { type: Integer, desc: 'User ID' }
  expose :name, documentation: { type: String, desc: 'Name' }
  expose :email, documentation: { type: String, desc: 'Email' }
  expose :posts, using: Entities::Post, documentation: { is_array: true }
end
```

### Entity Documentation Options

| Option | grape-swagger | grape-oas | Notes |
|--------|---------------|-----------|-------|
| `type` | ✅ | ✅ | Data type |
| `desc` | ✅ | ✅ | Description |
| `required` | ✅ | ✅ | Required field |
| `is_array` | ✅ | ✅ | Array of items |
| `values` | ✅ | ✅ | Enum values |
| `default` | ✅ | ✅ | Default value |
| `example` | ✅ | ✅ | Example value |
| `param_type` | ✅ | ✅ | Parameter type |
| `x` | ✅ | ✅ | Extensions |
| `nullable` | ❌ | ✅ | OAS 3.1 nullable |

### entity_name

```ruby
# Works in both
class Entities::User < Grape::Entity
  expose :id

  def self.entity_name
    'UserResponse'
  end
end
```

### Inheritance / allOf

```ruby
# Works in both (grape-swagger-entity required for grape-swagger)
class Entities::Pet < Grape::Entity
  expose :name, documentation: { type: String }
end

class Entities::Dog < Entities::Pet
  expose :breed, documentation: { type: String }
end
```

---

## Security Definitions

### API Key

```ruby
# Works in both
add_oas_documentation(
  security_definitions: {
    api_key: {
      type: 'apiKey',
      name: 'X-API-Key',
      in: 'header'
    }
  },
  security: [{ api_key: [] }]
)
```

### OAuth2

**Important**: Security definitions are passed through as-is. Use the correct format for your target OAS version.

```ruby
# OAS 2.0 format
add_oas_documentation(
  security_definitions: {
    oauth2: {
      type: 'oauth2',
      flow: 'accessCode',
      authorizationUrl: 'https://example.com/oauth/authorize',
      tokenUrl: 'https://example.com/oauth/token',
      scopes: {
        'read:users' => 'Read users',
        'write:users' => 'Write users'
      }
    }
  }
)

# OAS 3.x format
add_oas_documentation(
  security_definitions: {
    oauth2: {
      type: 'oauth2',
      flows: {
        authorizationCode: {
          authorizationUrl: 'https://example.com/oauth/authorize',
          tokenUrl: 'https://example.com/oauth/token',
          scopes: {
            'read:users' => 'Read users',
            'write:users' => 'Write users'
          }
        }
      }
    }
  }
)
```

### Per-Operation Security

```ruby
# Works in both
desc 'Admin endpoint', documentation: { security: [{ oauth2: ['admin'] }] }
get :admin do; end
```

---

## Extensions

Both gems support OpenAPI extensions (x-* properties):

```ruby
# Parameter extension
params do
  requires :id, type: Integer, documentation: { x: { internal: true } }
end

# Operation extension
desc 'Get user', x: { rate_limit: 100 }
get ':id' do; end
```

### Extension Levels

| Level | grape-swagger | grape-oas |
|-------|---------------|-----------|
| Root | ✅ `x:` in add_swagger_documentation | ✅ via info hash |
| Info | ✅ `info: { x: }` | ✅ `info: { x: }` |
| Operation | ✅ `desc 'x', x:` | ✅ `desc 'x', x:` |
| Path | ✅ `route_setting :x_path` | ❌ |
| Definition | ✅ `route_setting :x_def` | ❌ |
| Parameters | ✅ `documentation: { x: }` | ✅ `documentation: { x: }` |

---

## Feature Parity

### Full Parity

| Feature | Status |
|---------|--------|
| Basic endpoint documentation | ✅ |
| Parameter documentation | ✅ |
| Response documentation | ✅ |
| Grape::Entity support | ✅ |
| Security definitions | ✅ |
| Tags | ✅ |
| Hiding endpoints | ✅ |
| Hiding parameters | ✅ |
| Response headers | ✅ |
| Response examples | ✅ |
| Extensions (x-*) | ✅ |
| consumes/produces | ✅ |
| Deprecation | ✅ |
| Array responses | ✅ |
| Nested parameters | ✅ |
| File responses | ✅ |
| Default responses | ✅ |
| Multiple success/failure codes | ✅ |

### Partial Parity

| Feature | grape-swagger | grape-oas | Notes |
|---------|---------------|-----------|-------|
| OAuth middleware integration | ✅ | ❌ | Use standard Grape auth |
| Custom model parsers | ✅ | ❌ | Built-in introspection only |
| Multiple present (`as:`) | ✅ | ✅ | Fully supported |
| Root wrapping | ✅ | ❌ | Not implemented |
| Nested namespace standalone | ✅ | ❌ | Not implemented |
| Custom operationId (nickname) | ✅ | ❌ | Auto-generated only |
| body_name override | ✅ | ✅ | OAS 2.0 only |

---

## Features Not Yet Supported

These grape-swagger features are not currently available in grape-oas:

1. **OAuth Middleware Integration** (`endpoint_auth_wrapper`, `swagger_endpoint_guard`, `token_owner`)
   - Use standard Grape authentication instead

2. **Custom Model Parsers** (`GrapeSwagger.model_parsers.register`)
   - grape-oas uses built-in introspection for entities and contracts

3. **Multiple Present Responses** (`as:` key for combining multiple models)
   - Workaround: Create a combined entity

4. **Root Element Wrapping** (`route_setting :swagger, root:`)
   - Workaround: Create a wrapper entity

5. **Nested Namespace as Standalone** (`swagger: { nested: false }`)
   - All namespaces follow standard Grape routing

6. **Custom operationId** (`nickname:`)
   - operationId is auto-generated from method and path


---

## New Features in grape-oas

Features available in grape-oas but not in grape-swagger:

### 1. OpenAPI 3.0 and 3.1 Support

```ruby
# Generate different versions
GrapeOAS.generate(app: API, schema_type: :oas2)   # OpenAPI 2.0
GrapeOAS.generate(app: API, schema_type: :oas3)   # OpenAPI 3.0
GrapeOAS.generate(app: API, schema_type: :oas31)  # OpenAPI 3.1

# Or via query parameter
# /swagger_doc?oas=2
# /swagger_doc?oas=3
# /swagger_doc?oas=3.1
```

### 2. Programmatic Generation

```ruby
# Generate without mounting an endpoint
spec = GrapeOAS.generate(app: MyAPI, schema_type: :oas31)
File.write('openapi.json', JSON.pretty_generate(spec))
```

### 3. Full dry-struct/dry-types Support

```ruby
class CreateUserContract < Dry::Struct
  attribute :name, Types::String
  attribute :email, Types::String.constrained(format: /@/)
  attribute :age, Types::Integer.optional
  attribute :role, Types::String.enum('admin', 'user').default('user')
end

params do
  requires :user, type: CreateUserContract
end
```

### 4. OpenAPI 3.1 JSON Schema Features

```ruby
params do
  optional :data, type: Hash, documentation: {
    nullable: true,                    # type: ["object", "null"]
    additional_properties: false,
    unevaluated_properties: false,     # JSON Schema 2020-12
    '$defs': { Ref: { type: 'string' } }
  }
end
```

### 5. Suppress Default Error Response

```ruby
desc 'Endpoint without auto 400',
     documentation: { suppress_default_error_response: true }
```

### 6. Request Body for GET/DELETE

```ruby
# Opt-in request body for methods that normally don't have one
desc 'Search with body'
params do
  requires :query, type: Hash, documentation: { request_body: true }
end
get :search do; end
```

---

## Migration Checklist

- [ ] Replace `grape-swagger` and `grape-swagger-entity` with `grape-oas` in Gemfile
- [ ] Remove `require 'grape-swagger'` statements (Zeitwerk handles loading)
- [ ] Replace `add_swagger_documentation` with `add_oas_documentation` (or keep it - compatibility shim exists)
- [ ] Update `mount_path` to `oas_mount_path` (optional)
- [ ] Update OAuth2 security definitions format if targeting OAS 3.x
- [ ] Remove any `endpoint_auth_wrapper`/`swagger_endpoint_guard`/`token_owner` options
- [ ] Test generated output against your existing schema
- [ ] Update any code that depends on `nickname` (operationId is now auto-generated)
- [ ] Review any `as:` multiple present responses (not supported - create combined entity)
- [ ] Review any root element wrapping (not supported - create wrapper entity)

---

## Getting Help

- [grape-oas GitHub Issues](https://github.com/numbata/grape-oas/issues)
- [grape-oas README](../README.md)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
