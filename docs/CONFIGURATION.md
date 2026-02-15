# Configuration

This document covers all configuration options for Grape::OAS.

## Table of Contents

- [Global Options](#global-options)
- [Info Object](#info-object)
- [Nullable Strategy](#nullable-strategy)
- [Security Definitions](#security-definitions)
- [Tags](#tags)
- [Namespace Filtering](#namespace-filtering)

## Global Options

```ruby
add_oas_documentation(
  # API metadata
  host: 'api.example.com',           # API host (default: from request)
  base_path: '/v1',                   # Base path (default: from request)
  schemes: ['https'],                 # Supported schemes (OAS 2.0)

  # Server configuration (OAS 3.x)
  servers: [
    { url: 'https://api.example.com/v1', description: 'Production' },
    { url: 'https://staging-api.example.com/v1', description: 'Staging' }
  ],

  # Content types
  consumes: ['application/json'],     # Request content types
  produces: ['application/json'],     # Response content types

  # Documentation endpoint
  mount_path: '/swagger_doc',         # Path to mount docs (default: /swagger_doc)

  # Filtering
  models: [Entity::User, Entity::Post], # Pre-register entities
  namespace: 'users',                 # Filter to specific namespace
  tags: [                             # Tag definitions
    { name: 'users', description: 'User operations' },
    { name: 'posts', description: 'Post operations' }
  ]
)
```

## Info Object

```ruby
add_oas_documentation(
  info: {
    title: 'My API',
    version: '1.0.0',
    description: 'Full API description with **Markdown** support',
    terms_of_service: 'https://example.com/terms',
    contact: {
      name: 'API Support',
      url: 'https://example.com/support',
      email: 'support@example.com'
    },
    license: {
      name: 'MIT',
      url: 'https://opensource.org/licenses/MIT'
    }
  }
)
```

## Nullable Strategy

Control how nullable fields are represented in the generated schema. Each OpenAPI version has a default strategy, but you can override it for OAS 2.0 and OAS 3.0.

| Strategy | Output | Default for |
|----------|--------|-------------|
| `:keyword` | `"nullable": true` | OAS 3.0 |
| `:type_array` | `"type": ["string", "null"]` | OAS 3.1 (always) |
| `:extension` | `"x-nullable": true` | _(none)_ |

```ruby
# OAS 3.0 — default uses "nullable: true" keyword
GrapeOAS.generate(app: API, schema_type: :oas3)

# OAS 3.0 — use JSON Schema null unions instead
GrapeOAS.generate(app: API, schema_type: :oas3,
                  nullable_strategy: :type_array)

# OAS 2.0 — emit x-nullable extension for nullable fields
GrapeOAS.generate(app: API, schema_type: :oas2,
                  nullable_strategy: :extension)

# OAS 3.1 — always uses type arrays, nullable_strategy is ignored
GrapeOAS.generate(app: API, schema_type: :oas31)
```

**Note:** OAS 3.1 always uses `:type_array` (JSON Schema null unions) regardless of the `nullable_strategy` option, because `nullable` is not a valid keyword in OAS 3.1.

### Backward Compatibility

The legacy `nullable_keyword` option is still accepted for OAS 3.0 and mapped automatically:

| Legacy option | Equivalent |
|---------------|------------|
| `nullable_keyword: true` | `nullable_strategy: :keyword` |
| `nullable_keyword: false` | `nullable_strategy: :type_array` |

If both `nullable_strategy` and `nullable_keyword` are provided, `nullable_strategy` takes precedence. The `nullable_keyword` option has no effect on OAS 2.0 or OAS 3.1.

## Security Definitions

Security definitions are passed through directly to the OpenAPI output. Use the format appropriate for your target OpenAPI version.

### API Key Authentication

```ruby
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

### OAuth2 (OAS 2.0 format)

```ruby
add_oas_documentation(
  security_definitions: {
    oauth2: {
      type: 'oauth2',
      flow: 'accessCode',
      authorizationUrl: 'https://example.com/oauth/authorize',
      tokenUrl: 'https://example.com/oauth/token',
      scopes: {
        'read:users' => 'Read user data',
        'write:users' => 'Modify user data'
      }
    }
  },
  security: [{ oauth2: ['read:users'] }]
)
```

### OAuth2 (OAS 3.x format)

```ruby
add_oas_documentation(
  security_definitions: {
    oauth2: {
      type: 'oauth2',
      flows: {
        authorizationCode: {
          authorizationUrl: 'https://example.com/oauth/authorize',
          tokenUrl: 'https://example.com/oauth/token',
          scopes: {
            'read:users' => 'Read user data',
            'write:users' => 'Modify user data'
          }
        }
      }
    }
  },
  security: [{ oauth2: ['read:users'] }]
)
```

**Note:** Security definitions are passed through as-is. If you generate both OAS 2.0 and OAS 3.x from the same API, you may need to handle the format differences in your configuration.

## Tags

```ruby
add_oas_documentation(
  tags: [
    { name: 'users', description: 'User management operations' },
    { name: 'posts', description: 'Blog post operations', external_docs: { url: 'https://docs.example.com/posts' } }
  ]
)
```

## Namespace Filtering

Generate documentation for only a subset of your API:

```ruby
# Only include paths starting with /users
GrapeOAS.generate(app: API, schema_type: :oas3, namespace: 'users')
# Includes: /users, /users/{id}, /users/posts
# Excludes: /posts, /comments

# Filter to nested namespace
GrapeOAS.generate(app: API, schema_type: :oas3, namespace: 'users/posts')

# Works with or without leading slash
GrapeOAS.generate(app: API, namespace: '/users')  # Same as 'users'
```

This is useful for:
- Generating separate documentation for different API sections
- Creating focused documentation for specific consumers
- Reducing documentation size for large APIs
