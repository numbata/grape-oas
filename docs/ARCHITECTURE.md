# Architecture Overview

This document provides a high-level overview of Grape::OAS architecture and how its components work together to generate OpenAPI specifications.

## Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         GrapeOAS.generate                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ApiModelBuilder                           │
│  Parses Grape API routes and builds internal API model           │
│  Uses: Collector, Request, Response, Operation builders          │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│     Introspectors         │   │         ApiModel              │
│  - EntityIntrospector     │   │  Internal representation of   │
│  - DryIntrospector        │   │  the API specification        │
│  - Custom (via registry)  │   │  (paths, operations, schemas) │
└───────────────────────────┘   └───────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Exporters                               │
│  Convert ApiModel to OpenAPI JSON format                         │
│  - OAS2Schema (Swagger 2.0)                                      │
│  - OAS30Schema (OpenAPI 3.0)                                     │
│  - OAS31Schema (OpenAPI 3.1)                                     │
│  - Custom (via registry)                                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     OpenAPI JSON Output                          │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Input**: Grape API class with routes, parameters, and entity definitions
2. **Collection**: `Collector` gathers route metadata from Grape
3. **Building**: `ApiModelBuilder` constructs internal model using specialized builders
4. **Introspection**: `Introspectors` extract schemas from entities/contracts
5. **Export**: `Exporters` convert the model to target OpenAPI version
6. **Output**: JSON-serializable Hash representing the OpenAPI specification

## Extension Points

Grape::OAS provides two registries for extensibility:

### Introspector Registry

Register custom introspectors to support new schema definition formats:

```ruby
GrapeOAS.introspectors.register(MyIntrospector)
```

See [INTROSPECTORS.md](INTROSPECTORS.md) for details.

### Exporter Registry

Register custom exporters for new output formats:

```ruby
GrapeOAS.exporters.register(MyExporter, as: :custom_format)
```

See [EXPORTERS.md](EXPORTERS.md) for details.

## Directory Structure

```
lib/grape_oas/
├── api_model/              # Internal API representation models
│   ├── schema.rb           # Schema model (type, properties, etc.)
│   ├── operation.rb        # Operation model (endpoint metadata)
│   ├── path.rb             # Path model (URL pattern + operations)
│   └── ...
├── api_model_builders/     # Builders that construct the API model
│   ├── request.rb          # Request body/parameters builder
│   ├── response.rb         # Response builder
│   ├── operation.rb        # Operation builder
│   └── concerns/           # Shared builder concerns
├── introspectors/          # Schema extraction from entities
│   ├── base.rb             # Base interface for introspectors
│   ├── registry.rb         # Introspector registry
│   ├── entity_introspector.rb
│   └── dry_introspector.rb
├── exporter/               # OpenAPI JSON generators
│   ├── registry.rb         # Exporter registry
│   ├── oas2_schema.rb      # Swagger 2.0 exporter
│   ├── oas3_schema.rb      # OpenAPI 3.x base
│   ├── oas30_schema.rb     # OpenAPI 3.0 exporter
│   └── oas31_schema.rb     # OpenAPI 3.1 exporter
└── collector.rb            # Grape route collector
```

## Related Documentation

- [INTROSPECTORS.md](INTROSPECTORS.md) - Schema extraction system
- [EXPORTERS.md](EXPORTERS.md) - OpenAPI format generation
- [API_MODEL.md](API_MODEL.md) - Internal API representation
- [MIGRATING_FROM_GRAPE_SWAGGER.md](MIGRATING_FROM_GRAPE_SWAGGER.md) - Migration guide
