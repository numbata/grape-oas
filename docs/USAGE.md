# Usage Guide

This document covers detailed usage examples for Grape::OAS.

## Table of Contents

- [Documenting Endpoints](#documenting-endpoints)
- [Request Parameters](#request-parameters)
- [Response Documentation](#response-documentation)
- [Hiding Endpoints](#hiding-endpoints)
- [Entity Support](#entity-support)
- [OpenAPI Version Features](#openapi-version-features)

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

### Block Syntax

```ruby
desc 'Create a new user' do
  detail 'Creates a user with the provided attributes'
  tags ['users']
  consumes ['application/json']
  produces ['application/json']
end
```

## Request Parameters

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

## Response Documentation

### one_of Responses

```ruby
desc 'Get user or profile' do
  success one_of: [
    { model: Entity::User },
    { model: Entity::Profile }
  ]
end
```

**Notes:**
- `one_of` is a grape-oas extension and is not part of the upstream Grape DSL.
- If you mix `one_of` with regular `as:` response specs, `one_of` is ignored.
- `:as` is ignored within `one_of` items.
- `one_of` items must include `:model` or `:entity`.

### Basic Responses

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

### Multiple Success Responses

```ruby
desc 'Create user' do
  success [
    { code: 200, model: Entity::User, message: 'User found' },
    { code: 201, model: Entity::User, message: 'User created' }
  ]
end
```

### Response Headers

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

## Hiding Endpoints

### Hide Entire Endpoint

```ruby
desc 'Internal endpoint', hidden: true
get :internal do
  # ...
end
```

### Conditional Hiding

```ruby
desc 'Admin endpoint', hidden: -> { !current_user&.admin? }
get :admin do
  # ...
end
```

### Via Route Setting

```ruby
route_setting :swagger, hidden: true
get :hidden do
  # ...
end
```

### Hide Parameters

```ruby
params do
  requires :id, type: Integer
  optional :internal_flag, type: Boolean, documentation: { hidden: true }
end
```

## Entity Support

### Grape::Entity

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

### Using Entities

```ruby
desc 'List users' do
  success Entity::User, is_array: true
end
get do
  present User.all, with: Entity::User
end
```

### Dry::Struct Contracts

```ruby
class CreateUserContract < Dry::Struct
  attribute :name, Types::String
  attribute :email, Types::String.constrained(format: URI::MailTo::EMAIL_REGEXP)
  attribute :age, Types::Integer.optional.default(nil)
  attribute :role, Types::String.enum('admin', 'user', 'guest').default('user')
end

params do
  requires :user, type: CreateUserContract
end
```

## OpenAPI Version Features

### OpenAPI 2.0 (Swagger)

```ruby
GrapeOAS.generate(app: API, schema_type: :oas2)

add_oas_documentation(
  schemes: ['https', 'http'],  # Only in OAS 2.0
  consumes: ['application/json'],
  produces: ['application/json']
)
```

### OpenAPI 3.0

```ruby
GrapeOAS.generate(app: API, schema_type: :oas3)

add_oas_documentation(
  servers: [
    { url: 'https://api.example.com', description: 'Production' }
  ]
)
```

### OpenAPI 3.1

OpenAPI 3.1 aligns with JSON Schema draft 2020-12:

```ruby
GrapeOAS.generate(app: API, schema_type: :oas31)

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
- `examples` uses array format per JSON Schema 2020-12
