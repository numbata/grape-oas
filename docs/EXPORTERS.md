# Exporters

Exporters convert the internal API model into OpenAPI specification JSON. Grape::OAS includes exporters for OpenAPI 2.0 (Swagger), 3.0, and 3.1, and provides a registry for adding custom exporters.

## Built-in Exporters

| Exporter | Aliases | OpenAPI Version |
|----------|---------|-----------------|
| `OAS2Schema` | `:oas2` | 2.0 (Swagger) |
| `OAS30Schema` | `:oas3`, `:oas30` | 3.0.x |
| `OAS31Schema` | `:oas31` | 3.1.x |

### Usage

```ruby
# Generate OpenAPI 3.0 (default)
schema = GrapeOAS.generate(app: MyAPI)

# Generate Swagger 2.0
schema = GrapeOAS.generate(app: MyAPI, schema_type: :oas2)

# Generate OpenAPI 3.1
schema = GrapeOAS.generate(app: MyAPI, schema_type: :oas31)
```

### Version Differences

#### OpenAPI 2.0 (Swagger)
- Uses `swagger: "2.0"` version field
- Request body via `in: body` parameters
- `definitions` for schema references
- `host`, `basePath`, `schemes` for server info
- No built-in nullable support; use `nullable_strategy: :extension` to emit `x-nullable: true`
- **Composition types**: Not all composition types are natively supported. The exporter uses a fallback type while preserving schema extensions for downstream consumers

#### OpenAPI 3.0
- Uses `openapi: "3.0.0"` version field
- Separate `requestBody` object
- `components/schemas` for schema references
- `servers` array for server info
- `nullable: true` for nullable types (default); configurable via `nullable_strategy`
- **Composition types**: Native support for `oneOf`, `anyOf`, `allOf`

#### OpenAPI 3.1
- Uses `openapi: "3.1.0"` version field
- Full JSON Schema compatibility
- `type: ["string", "null"]` instead of `nullable` (always; not configurable)
- `examples` array instead of singular `example`
- License requires `identifier` OR `url` (not both)

See [Configuration > Nullable Strategy](CONFIGURATION.md#nullable-strategy) for details on controlling nullable representation.

## Exporter Registry

The registry maps schema type symbols to exporter classes.

### Accessing the Registry

```ruby
# Get the global registry
registry = GrapeOAS.exporters

# List registered types
registry.schema_types  # => [:oas2, :oas3, :oas30, :oas31]

# Check if a type is registered
registry.registered?(:oas3)  # => true

# Get exporter class for a type
registry.for(:oas3)  # => GrapeOAS::Exporter::OAS30Schema
```

### The `Exporter.for` Method

```ruby
# Shorthand for registry lookup
exporter_class = GrapeOAS::Exporter.for(:oas31)
# => GrapeOAS::Exporter::OAS31Schema

# Use it directly
exporter = exporter_class.new(api_model: my_api_model)
json = exporter.generate
```

## Creating Custom Exporters

To support new output formats or customize existing ones:

```ruby
class MyCustomExporter
  def initialize(api_model:)
    @api = api_model
  end

  def generate
    {
      "my_format_version" => "1.0",
      "title" => @api.title,
      "endpoints" => build_endpoints
    }
  end

  private

  def build_endpoints
    @api.paths.flat_map do |path|
      path.operations.map do |op|
        {
          "method" => op.method,
          "path" => path.path,
          "summary" => op.summary,
          "parameters" => build_parameters(op)
        }
      end
    end
  end

  def build_parameters(operation)
    operation.parameters.map do |param|
      {
        "name" => param.name,
        "in" => param.location,
        "type" => param.schema&.type
      }
    end
  end
end
```

### Extending Built-in Exporters

You can extend existing exporters to customize behavior:

```ruby
class MyOAS3Exporter < GrapeOAS::Exporter::OAS30Schema
  private

  # Override to customize info section
  def build_info
    info = super
    info["x-custom-field"] = "custom value"
    info
  end

  # Override to add custom root fields
  def generate
    result = super
    result["x-generator"] = "MyApp v1.0"
    result
  end
end
```

### Registering Custom Exporters

```ruby
# Register with a single alias
GrapeOAS.exporters.register(MyCustomExporter, as: :custom)

# Register with multiple aliases
GrapeOAS.exporters.register(MyOAS3Exporter, as: %i[my_oas3 custom_oas3])

# Now use it
schema = GrapeOAS.generate(app: MyAPI, schema_type: :custom)
```

### Unregistering Exporters

```ruby
# Remove a single type
GrapeOAS.exporters.unregister(:custom)

# Remove multiple types
GrapeOAS.exporters.unregister(:custom, :my_oas3)
```

## Exporter Interface

Every exporter must implement:

| Method | Description |
|--------|-------------|
| `initialize(api_model:)` | Constructor receiving the API model |
| `generate` | Returns a Hash (JSON-serializable OpenAPI spec) |

The `api_model` parameter is an `ApiModel::Api` instance containing:
- `title` - API title
- `version` - API version string
- `paths` - Array of `ApiModel::Path` objects
- `tag_defs` - Tag definitions
- `security_definitions` - Security schemes
- `servers` - Server URLs

## Third-Party Gems

To create a gem that adds exporter support:

```ruby
# lib/grape_oas_my_format.rb
require 'grape_oas'
require 'grape_oas_my_format/exporter'

# Auto-register on load
GrapeOAS.exporters.register(
  GrapeOASMyFormat::Exporter,
  as: :my_format
)
```

Users just need to add your gem and use the format:

```ruby
gem 'grape-oas'
gem 'grape-oas-my-format'

# In code
schema = GrapeOAS.generate(app: MyAPI, schema_type: :my_format)
```

## Exporter Hierarchy

```
OAS3Schema (base for 3.x)
├── OAS30Schema (:oas3, :oas30)
└── OAS31Schema (:oas31)

OAS2Schema (:oas2) - standalone
```

When creating custom exporters, consider which base class suits your needs:
- Extend `OAS3Schema` for OpenAPI 3.x variants
- Extend `OAS2Schema` for Swagger 2.x variants
- Create standalone class for completely different formats
