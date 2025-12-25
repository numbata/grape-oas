# Grape::OAS

[![Gem Version](https://badge.fury.io/rb/grape-oas.svg)](https://badge.fury.io/rb/grape-oas)
[![CI](https://github.com/numbata/grape-oas/actions/workflows/ci.yml/badge.svg)](https://github.com/numbata/grape-oas/actions)

OpenAPI Specification (OAS) documentation generator for [Grape](https://github.com/ruby-grape/grape) APIs. Supports OpenAPI 2.0 (Swagger), 3.0, and 3.1 specifications.

## Table of Contents

- [Why Grape::OAS?](#why-grapeoas)
- [Features](#features)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Quick Start](#quick-start)
  - [Mount Documentation Endpoint](#mount-documentation-endpoint)
  - [Manual Generation](#manual-generation)
  - [Rake Tasks](#rake-tasks)
- [Documentation](#documentation)
- [Basic Usage](#basic-usage)
  - [Documenting Endpoints](#documenting-endpoints)
  - [Response Documentation](#response-documentation)
  - [Entity Definition](#entity-definition)
- [Extensibility](#extensibility)
  - [Custom Introspectors](#custom-introspectors)
  - [Custom Exporters](#custom-exporters)
- [Related Projects](#related-projects)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)


## Why Grape::OAS?

Grape::OAS is built around a **DTO (Data Transfer Object) architecture** that separates collecting API metadata from generating schemas. This clean separation makes the codebase easier to reason about and enables support for multiple output formats (OAS 2.0, 3.0, 3.1) from the same API definition.

## Features

- **Multi-version support**: Generate OAS 2.0, 3.0, or 3.1 from the same API
- **Entity integration**: Works with [grape-entity](https://github.com/ruby-grape/grape-entity) and [dry-struct](https://dry-rb.org/gems/dry-struct/)
- **Automatic type inference**: Derives OpenAPI types from Grape parameter definitions
- **Flexible output**: Mount as an endpoint or generate programmatically

## Compatibility

| grape-oas | grape | grape-entity | dry-struct | Ruby |
|-----------|-------|--------------|------------|------|
| 0.1.x | >= 3.0 | >= 0.7 | >= 1.0 | >= 3.2 |

## Installation

```ruby
gem 'grape-oas'
```

For entity support:

```ruby
gem 'grape-entity'  # For grape-entity support
gem 'dry-struct'    # For dry-struct contract support
```

## Quick Start

### Mount Documentation Endpoint

```ruby
class API < Grape::API
  format :json

  add_oas_documentation(
    info: {
      title: 'My API',
      version: '1.0.0'
    }
  )

  resource :users do
    desc 'List users', entity: Entity::User
    get { User.all }
  end
end
```

Documentation available at:
- `/swagger_doc` - OpenAPI 3.0 (default)
- `/swagger_doc?oas=2` - OpenAPI 2.0
- `/swagger_doc?oas=3.1` - OpenAPI 3.1

### Manual Generation

```ruby
# Generate OpenAPI 3.0 spec
spec = GrapeOAS.generate(app: API, schema_type: :oas3)
puts JSON.pretty_generate(spec)
```

### Rake Tasks

```ruby
# In Rakefile
require 'grape_oas/tasks'
```

```bash
rake grape_oas:generate[MyAPI,oas31,spec/openapi.json]
```

## Documentation

| Document | Description |
|----------|-------------|
| [Configuration](docs/CONFIGURATION.md) | All configuration options |
| [Usage Guide](docs/USAGE.md) | Detailed usage examples |
| [Architecture](docs/ARCHITECTURE.md) | System architecture overview |
| [Introspectors](docs/INTROSPECTORS.md) | Custom introspector development |
| [Exporters](docs/EXPORTERS.md) | Custom exporter development |
| [API Model](docs/API_MODEL.md) | Internal API model reference |

## Basic Usage

### Documenting Endpoints

```ruby
desc 'Get a user by ID',
  detail: 'Returns detailed user information',
  tags: ['users']

params do
  requires :id, type: Integer, desc: 'User ID'
end

get ':id' do
  User.find(params[:id])
end
```

### Response Documentation

```ruby
desc 'Get user' do
  success Entity::User
  failure [[404, 'Not Found'], [500, 'Server Error']]
end
```

### Entity Definition

```ruby
class Entity::User < Grape::Entity
  expose :id, documentation: { type: Integer }
  expose :name, documentation: { type: String }
  expose :posts, using: Entity::Post, documentation: { is_array: true }
end
```

## Extensibility

### Custom Introspectors

```ruby
class MyModelIntrospector
  extend GrapeOAS::Introspectors::Base

  def self.handles?(subject)
    subject.is_a?(Class) && subject < MyBaseModel
  end

  def self.build_schema(subject, stack: [], registry: {})
    GrapeOAS::ApiModel::Schema.new(type: "object", canonical_name: subject.name)
  end
end

GrapeOAS.introspectors.register(MyModelIntrospector)
```

### Custom Exporters

```ruby
GrapeOAS.exporters.register(MyCustomExporter, as: :custom)
schema = GrapeOAS.generate(app: API, schema_type: :custom)
```

## Related Projects

| Project | Description |
|---------|-------------|
| [grape](https://github.com/ruby-grape/grape) | REST-like API framework for Ruby |
| [grape-entity](https://github.com/ruby-grape/grape-entity) | Entity exposure for Grape APIs |
| [grape-swagger](https://github.com/ruby-grape/grape-swagger) | OpenAPI documentation for Grape APIs |
| [grape-swagger-entity](https://github.com/ruby-grape/grape-swagger-entity) | grape-swagger adapter for grape-entity |
| [oas_grape](https://github.com/a-chacon/oas_grape) | Another OpenAPI 3.1 generator for Grape |

## Development

```bash
git clone https://github.com/numbata/grape-oas.git
cd grape-oas
bin/setup
bundle exec rake test
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/numbata/grape-oas. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License. Copyright (c) Andrei Subbota.
