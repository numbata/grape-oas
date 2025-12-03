# Grape::OAS

[![Gem Version](https://badge.fury.io/rb/grape-oas.svg)](https://badge.fury.io/rb/grape-oas)
[![Build Status](https://github.com/numbata/grape-oas/actions/workflows/test.yml/badge.svg)](https://github.com/numbata/grape-oas/actions)
[![Code Climate](https://codeclimate.com/github/numbata/grape-oas.svg)](https://codeclimate.com/github/numbata/grape-oas)

OpenAPI Specification (OAS) documentation generator for [Grape](https://github.com/ruby-grape/grape) APIs. Supports OpenAPI 2.0 (Swagger), 3.0, and 3.1 specifications.

## Table of Contents

- [What is Grape::OAS?](#what-is-grapeoas)
- [Migrating from grape-swagger](#migrating-from-grape-swagger)
- [Related Projects](#related-projects)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Usage](#usage)
  - [Mounting Documentation Endpoint](#mounting-documentation-endpoint)
  - [Manual Generation](#manual-generation)
  - [Rake Tasks](#rake-tasks)
- [Configuration](#configuration)
  - [Global Options](#global-options)
  - [Info Object](#info-object)
  - [Security Definitions](#security-definitions)
  - [Tags](#tags)
- [Documenting Endpoints](#documenting-endpoints)
  - [Basic Documentation](#basic-documentation)
  - [Request Parameters](#request-parameters)
  - [Response Documentation](#response-documentation)
  - [Hiding Endpoints](#hiding-endpoints)
- [Entity Support](#entity-support)
  - [Grape::Entity](#grapeentity)
  - [Dry::Struct Contracts](#drystruct-contracts)
- [OpenAPI Version-Specific Features](#openapi-version-specific-features)
  - [OpenAPI 2.0 (Swagger)](#openapi-20-swagger)
  - [OpenAPI 3.0](#openapi-30)
  - [OpenAPI 3.1](#openapi-31)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Migrating from grape-swagger

If you're currently using [grape-swagger](https://github.com/ruby-grape/grape-swagger), see our comprehensive **[Migration Guide](docs/MIGRATING_FROM_GRAPE_SWAGGER.md)** which covers:

- Key differences between the gems
- Configuration option mapping
- Feature parity comparison
- Step-by-step migration checklist

grape-oas provides a compatibility shim for `add_swagger_documentation`, so basic migrations may work with minimal changes.

## What is Grape::OAS?

Grape::OAS is a Ruby gem that automatically generates OpenAPI Specification (formerly Swagger) documentation from your [Grape](https://github.com/ruby-grape/grape) API definitions. It introspects your API routes, parameters, and response definitions to produce valid OpenAPI 2.0, 3.0, or 3.1 JSON documents.

Key features:

- **Multi-version support**: Generate OAS 2.0, 3.0, or 3.1 specifications from the same API
- **Entity integration**: Works with [grape-entity](https://github.com/ruby-grape/grape-entity) and [dry-struct](https://dry-rb.org/gems/dry-struct/) for schema generation
- **Automatic type inference**: Derives OpenAPI types from Grape parameter definitions
- **Flexible output**: Mount as an endpoint or generate programmatically
- **Comprehensive validation support**: Translates Grape validators to OpenAPI constraints

## Related Projects

| Project | Description |
|---------|-------------|
| [grape](https://github.com/ruby-grape/grape) | REST-like API framework for Ruby |
| [grape-swagger](https://github.com/ruby-grape/grape-swagger) | Alternative Swagger documentation for Grape |
| [grape-entity](https://github.com/ruby-grape/grape-entity) | Entity exposure for Grape APIs |
| [grape-swagger-entity](https://github.com/ruby-grape/grape-swagger-entity) | grape-swagger adapter for grape-entity |

## Compatibility

| grape-oas | grape | grape-entity | dry-struct | Ruby |
|-----------|-------|--------------|------------|------|
| 0.1.x | >= 3.0 | >= 0.7 | >= 1.0 | >= 3.1 |

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'grape-oas'
```

And then execute:

```bash
$ bundle install
```

Or install it directly:

```bash
$ gem install grape-oas
```

For entity support, add the relevant gems:

```ruby
# For grape-entity support
gem 'grape-entity'

# For dry-struct contract support
gem 'dry-struct'
```

## Usage

### Mounting Documentation Endpoint

Add the documentation endpoint to your Grape API:

```ruby
class API < Grape::API
  format :json

  # add_oas_documentation can be placed anywhere in your API class.
  # Routes are captured at request time, so order doesn't matter.
  add_oas_documentation(
    host: 'api.example.com',
    base_path: '/v1',
    schemes: ['https'],
    info: {
      title: 'My API',
      version: '1.0.0',
      description: 'API documentation'
    }
  )

  # Your API endpoints...
  resource :users do
    get do
      # ...
    end
  end
end
```

The documentation will be available at `/swagger_doc` by default. Switch between OpenAPI versions using the `oas` query parameter:

- `/swagger_doc` or `/swagger_doc?oas=2` - OpenAPI 2.0 (Swagger)
- `/swagger_doc?oas=3` - OpenAPI 3.0
- `/swagger_doc?oas=3.1` - OpenAPI 3.1

### Manual Generation

Generate OpenAPI specifications programmatically:

```ruby
# OpenAPI 2.0 (Swagger)
spec = GrapeOAS.generate(app: API, schema_type: :oas2)

# OpenAPI 3.0
spec = GrapeOAS.generate(app: API, schema_type: :oas3)

# OpenAPI 3.1
spec = GrapeOAS.generate(app: API, schema_type: :oas31)

# Output as JSON
puts JSON.pretty_generate(spec)
```

**Note:** When using `GrapeOAS.generate` directly, call it **after** all routes are defined (e.g., at application boot time or in a rake task). Unlike the mounted endpoint, manual generation captures routes at call time.

### Rake Tasks

Grape::OAS provides rake tasks for common operations. Add to your `Rakefile`:

```ruby
require 'grape_oas/tasks'
```

Available tasks:

```bash
# Generate OpenAPI spec to file
$ rake grape_oas:generate[MyAPI,oas31,spec/openapi.json]

# Validate generated spec (requires swagger-cli or similar)
$ rake grape_oas:validate[spec/openapi.json]
```

## Configuration

### Global Options

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
  tags: [                             # Tag definitions
    { name: 'users', description: 'User operations' },
    { name: 'posts', description: 'Post operations' }
  ]
)
```

### Info Object

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

### Security Definitions

Security definitions are passed through directly to the OpenAPI output. Use the format appropriate for your target OpenAPI version.

**API Key Authentication:**

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

**OAuth2 (OAS 2.0 format):**

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

**OAuth2 (OAS 3.x format):**

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

### Tags

```ruby
add_oas_documentation(
  tags: [
    { name: 'users', description: 'User management operations' },
    { name: 'posts', description: 'Blog post operations', external_docs: { url: 'https://docs.example.com/posts' } }
  ]
)
```

## Documenting Endpoints

### Basic Documentation

```ruby
desc 'Get a user by ID',
  detail: 'Returns detailed user information including profile data',
  tags: ['users'],
  deprecated: false

params do
  requires :id, type: Integer, desc: 'User ID'
end

get ':id' do
  User.find(params[:id])
end
```

Using the block syntax:

```ruby
desc 'Create a new user' do
  detail 'Creates a user with the provided attributes'
  tags ['users']
  consumes ['application/json']
  produces ['application/json']
end
```

### Request Parameters

```ruby
params do
  # Required parameters
  requires :name, type: String, desc: 'User name'
  requires :email, type: String, desc: 'Email address', regexp: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i

  # Optional parameters with defaults
  optional :role, type: String, default: 'user', values: ['admin', 'user', 'guest']
  optional :age, type: Integer, desc: 'Age in years', documentation: { minimum: 0, maximum: 150 }

  # Array parameters
  optional :tags, type: Array[String], desc: 'User tags'
  optional :scores, type: Array[Integer], desc: 'Score values'

  # Nested objects
  optional :address, type: Hash do
    requires :street, type: String
    requires :city, type: String
    optional :zip, type: String
  end

  # File uploads
  optional :avatar, type: File, desc: 'Profile picture'

  # Documentation extras
  optional :metadata, type: Hash, documentation: {
    example: { key: 'value' },
    additional_properties: true
  }
end
```

### Response Documentation

```ruby
desc 'Get user' do
  success Entity::User                    # 200 response with entity
  failure [[400, 'Bad Request'], [404, 'Not Found']]

  # Or with entities for error responses
  failure [
    [400, 'Bad Request', Entity::Error],
    [404, 'Not Found', Entity::Error],
    [500, 'Server Error']
  ]
end
```

Multiple success responses:

```ruby
desc 'Create user' do
  success [
    { code: 200, model: Entity::User, message: 'User found' },
    { code: 201, model: Entity::User, message: 'User created' }
  ]
end
```

Response with headers:

```ruby
desc 'Create user' do
  success Entity::User, headers: {
    'X-Request-Id' => {
      description: 'Unique request identifier',
      type: 'string'
    },
    'Location' => {
      description: 'URL of created resource',
      type: 'string'
    }
  }
end
```

### Hiding Endpoints

Hide endpoints from documentation:

```ruby
# Hide entire endpoint
desc 'Internal endpoint', hidden: true
get :internal do
  # ...
end

# Conditional hiding
desc 'Admin endpoint', hidden: -> { !current_user&.admin? }
get :admin do
  # ...
end

# Hide via route_setting
route_setting :swagger, hidden: true
get :hidden do
  # ...
end
```

Hide parameters:

```ruby
params do
  requires :id, type: Integer
  optional :internal_flag, type: Boolean, documentation: { hidden: true }
end
```

## Entity Support

### Grape::Entity

Define entities for response schemas:

```ruby
module Entity
  class User < Grape::Entity
    expose :id, documentation: { type: Integer, desc: 'User ID' }
    expose :name, documentation: { type: String, desc: 'Full name' }
    expose :email, documentation: { type: String, desc: 'Email address' }
    expose :created_at, documentation: { type: DateTime, desc: 'Creation timestamp' }

    # Nested entities
    expose :posts, using: Entity::Post, documentation: { is_array: true }

    # Conditional exposure
    expose :admin_notes, if: :admin?, documentation: { type: String }
  end

  class Post < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :title, documentation: { type: String }
    expose :body, documentation: { type: String }
  end
end
```

Use entities in endpoints:

```ruby
desc 'List users' do
  success Entity::User, is_array: true
end
get do
  present User.all, with: Entity::User
end
```

### Dry::Struct Contracts

Use dry-struct for request validation and documentation:

```ruby
class CreateUserContract < Dry::Struct
  attribute :name, Types::String
  attribute :email, Types::String.constrained(format: URI::MailTo::EMAIL_REGEXP)
  attribute :age, Types::Integer.optional.default(nil)
  attribute :role, Types::String.enum('admin', 'user', 'guest').default('user')
end

# In your endpoint
params do
  requires :user, type: CreateUserContract
end
```

## OpenAPI Version-Specific Features

### OpenAPI 2.0 (Swagger)

```ruby
# Generate OAS 2.0
GrapeOAS.generate(app: API, schema_type: :oas2)

# OAS 2.0 specific options
add_oas_documentation(
  schemes: ['https', 'http'],  # Only in OAS 2.0
  consumes: ['application/json'],
  produces: ['application/json']
)
```

### OpenAPI 3.0

```ruby
# Generate OAS 3.0
GrapeOAS.generate(app: API, schema_type: :oas3)

# OAS 3.0 specific features
add_oas_documentation(
  servers: [
    { url: 'https://api.example.com', description: 'Production' }
  ]
)

# Request body (replaces body parameters)
params do
  requires :data, type: Hash, documentation: { in: 'body' } do
    requires :name, type: String
  end
end
```

### OpenAPI 3.1

OpenAPI 3.1 aligns with JSON Schema draft 2020-12:

```ruby
# Generate OAS 3.1
GrapeOAS.generate(app: API, schema_type: :oas31)

# OAS 3.1 specific documentation options
desc 'Get widget' do
  documentation(
    nullable: true,                    # type: [..., 'null']
    additional_properties: false,      # Strict object validation
    unevaluated_properties: false,     # JSON Schema 2020-12
    '$defs': {                         # Local schema definitions
      WidgetRef: { type: 'string', format: 'uuid' }
    }
  )
end

params do
  # Nullable parameters
  optional :id, type: Integer, documentation: { nullable: true }

  # Examples (array format in 3.1)
  optional :status, type: String, documentation: {
    examples: ['active', 'inactive', 'pending']
  }
end
```

Notes for OpenAPI 3.1:

- `nullable: true` produces `type: ["string", "null"]` instead of `nullable: true`
- `additional_properties` and `unevaluated_properties` are passed through
- `$defs` are emitted in the schema output
- `examples` uses array format per JSON Schema 2020-12
- Operations without `summary` fall back to first sentence of `description`, then humanized `operationId`

## Development

After checking out the repo, run `bin/setup` to install dependencies:

```bash
$ git clone https://github.com/numbata/grape-oas.git
$ cd grape-oas
$ bin/setup
```

Run the test suite:

```bash
$ bundle exec rake test
```

Run linting:

```bash
$ bundle exec rubocop
```

Run all checks:

```bash
$ bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/numbata/grape-oas.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Ensure tests pass (`bundle exec rake`)
5. Ensure code style passes (`bundle exec rubocop`)
6. Update CHANGELOG.md
7. Commit your changes (`git commit -am 'Add some feature'`)
8. Push to the branch (`git push origin my-new-feature`)
9. Create a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Copyright (c) Andrei Subbota
