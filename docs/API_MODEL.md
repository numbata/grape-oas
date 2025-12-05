# API Model

The API Model is Grape::OAS's internal representation of an OpenAPI specification. It serves as a version-agnostic intermediate format between Grape API introspection and the final OpenAPI JSON output.

## Overview

```
Grape API → ApiModelBuilder → API Model → Exporter → OpenAPI JSON
```

The API Model decouples the parsing logic from the export format, allowing:
- Single introspection pass for multiple output formats
- Clean separation between data collection and serialization
- Easier testing of individual components

## Model Classes

All model classes inherit from `Node`, which provides:
- Unique ID generation for component references
- `ref` method for `$ref` URI generation
- `bucket` class method for OpenAPI component section names

### API

The root container for the entire API specification.

```ruby
GrapeOAS::ApiModel::API
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `title` | String | API title |
| `version` | String | API version string |
| `paths` | Set<Path> | Collection of path objects |
| `servers` | Array<Hash> | Server URLs (OAS3) |
| `tag_defs` | Set | Tag definitions |
| `components` | Hash | Reusable components |
| `host` | String | API host (OAS2) |
| `base_path` | String | Base path (OAS2) |
| `schemes` | Array<String> | URL schemes (OAS2) |
| `security_definitions` | Hash | Security scheme definitions |
| `security` | Array | Global security requirements |
| `registered_schemas` | Array | Schemas registered for `$ref` |

**Methods:**
- `add_path(path)` - Add a path to the API
- `add_tags(*tags)` - Add tag definitions

### Path

Represents a URL path pattern with its operations.

```ruby
GrapeOAS::ApiModel::Path
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `template` | String | Path template (e.g., `/users/{id}`) |
| `operations` | Hash | HTTP method → Operation mapping |

**Methods:**
- `add_operation(operation)` - Add an operation, keyed by HTTP method
- `[](method)` - Get operation by HTTP method

### Operation

Represents a single API endpoint (HTTP method + path).

```ruby
GrapeOAS::ApiModel::Operation
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `http_method` | String | HTTP method (get, post, etc.) |
| `operation_id` | String | Unique operation identifier |
| `summary` | String | Short description |
| `description` | String | Detailed description |
| `deprecated` | Boolean | Deprecation status |
| `parameters` | Array<Parameter> | Operation parameters |
| `request_body` | RequestBody | Request body (OAS3) |
| `responses` | Hash | Status code → Response mapping |
| `tag_names` | Array<String> | Associated tags |
| `security` | Array | Security requirements |
| `extensions` | Hash | OpenAPI extensions (`x-*`) |
| `consumes` | Array<String> | Request content types |
| `produces` | Array<String> | Response content types |
| `suppress_default_error_response` | Boolean | Skip auto-generated error response |

**Methods:**
- `add_parameter(param)` - Add a parameter
- `add_parameters(params)` - Add multiple parameters
- `add_response(response)` - Add a response
- `response(status)` - Get response by status code

### Parameter

Represents a request parameter (path, query, header, cookie).

```ruby
GrapeOAS::ApiModel::Parameter
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `location` | String | Parameter location (`path`, `query`, `header`, `cookie`) |
| `name` | String | Parameter name |
| `required` | Boolean | Whether parameter is required |
| `description` | String | Parameter description |
| `schema` | Schema | Parameter data type schema |
| `collection_format` | String | Array format (OAS2: `csv`, `ssv`, `pipes`) |

### RequestBody

Represents a request body (OAS3 only; OAS2 uses body parameters).

```ruby
GrapeOAS::ApiModel::RequestBody
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `description` | String | Request body description |
| `required` | Boolean | Whether body is required |
| `media_types` | Hash | Content type → MediaType mapping |
| `extensions` | Hash | OpenAPI extensions |
| `body_name` | String | OAS2 body parameter name |

**Methods:**
- `add_media_type(media_type)` - Add a media type

### Response

Represents an HTTP response.

```ruby
GrapeOAS::ApiModel::Response
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `http_status` | Integer/String | HTTP status code |
| `description` | String | Response description |
| `media_types` | Hash | Content type → MediaType mapping |
| `headers` | Hash | Response headers |
| `extensions` | Hash | OpenAPI extensions |
| `examples` | Hash | Response examples |

**Methods:**
- `add_media_type(media_type)` - Add a media type

### MediaType

Represents a content type with its schema.

```ruby
GrapeOAS::ApiModel::MediaType
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `mime_type` | String | MIME type (e.g., `application/json`) |
| `schema` | Schema | Content schema |
| `examples` | Hash | Content examples |
| `extensions` | Hash | OpenAPI extensions |

### Schema

Represents a data type schema (JSON Schema-based).

```ruby
GrapeOAS::ApiModel::Schema
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `canonical_name` | String | Name for `$ref` (e.g., `User`) |
| `type` | String | JSON Schema type |
| `format` | String | Format hint (e.g., `email`, `date-time`) |
| `properties` | Hash | Object properties |
| `items` | Schema | Array item schema |
| `description` | String | Schema description |
| `required` | Array<String> | Required property names |
| `nullable` | Boolean | Nullable (OAS3.0) |
| `enum` | Array | Allowed values |
| `additional_properties` | Schema/Boolean | Additional properties schema |
| `unevaluated_properties` | Boolean | JSON Schema 2020-12 keyword |
| `defs` | Hash | Local schema definitions |
| `examples` | Array | Schema examples |
| `extensions` | Hash | OpenAPI extensions |
| `min_length` | Integer | Minimum string length |
| `max_length` | Integer | Maximum string length |
| `pattern` | String | Regex pattern |
| `minimum` | Numeric | Minimum value |
| `maximum` | Numeric | Maximum value |
| `exclusive_minimum` | Numeric/Boolean | Exclusive minimum |
| `exclusive_maximum` | Numeric/Boolean | Exclusive maximum |
| `min_items` | Integer | Minimum array items |
| `max_items` | Integer | Maximum array items |
| `discriminator` | Hash | Polymorphism discriminator |
| `all_of` | Array<Schema> | allOf composition |
| `one_of` | Array<Schema> | oneOf composition |
| `any_of` | Array<Schema> | anyOf composition |

**Methods:**
- `add_property(name, schema, required: false)` - Add object property
- `empty?` - Check if schema has no properties or compositions

## Node Base Class

All model classes inherit from `Node`:

```ruby
class Node
  attr_reader :id

  def initialize(node_id: nil)
    @id = node_id || generate_id  # UUID
  end

  def ref
    "#/components/#{self.class.bucket}/#{id}"
  end

  def self.bucket
    # Returns OpenAPI component section name
    # "Schema" → "schemas"
    # "RequestBody" → "requestBodies"
  end
end
```

The `bucket` method handles irregular pluralization according to OpenAPI spec:
- `Schema` → `schemas`
- `Parameter` → `parameters`
- `RequestBody` → `requestBodies`
- `Response` → `responses`
- `SecurityScheme` → `securitySchemes`

## Building the Model

The `ApiModelBuilder` constructs the model from a Grape API:

```ruby
# Internal usage
builder = GrapeOAS::ApiModelBuilder.new(title: "My API", version: "1.0.0")
builder.add_app(MyGrapeAPI)
api_model = builder.api  # => ApiModel::API instance

# Public API (preferred)
schema = GrapeOAS.generate(app: MyGrapeAPI)
```

The builder uses specialized sub-builders:
- `OperationBuilder` - Builds operations from route metadata
- `RequestBuilder` - Handles parameters and request bodies
- `ResponseBuilder` - Constructs response objects
- `TagBuilder` - Manages tag extraction and definitions

## Working with Schemas

### Creating Schemas

```ruby
# Simple type
string_schema = GrapeOAS::ApiModel::Schema.new(type: "string")

# Object with properties
user_schema = GrapeOAS::ApiModel::Schema.new(
  type: "object",
  canonical_name: "User"
)
user_schema.add_property("id", GrapeOAS::ApiModel::Schema.new(type: "integer"), required: true)
user_schema.add_property("name", GrapeOAS::ApiModel::Schema.new(type: "string"))

# Array
users_schema = GrapeOAS::ApiModel::Schema.new(
  type: "array",
  items: user_schema
)

# Composition
response_schema = GrapeOAS::ApiModel::Schema.new(
  one_of: [success_schema, error_schema]
)
```

### Schema References

When a schema has a `canonical_name`, exporters can generate `$ref` pointers:

```ruby
schema = GrapeOAS::ApiModel::Schema.new(
  canonical_name: "User",
  type: "object"
)

# Exporter generates:
# { "$ref": "#/components/schemas/User" }  (OAS3)
# { "$ref": "#/definitions/User" }         (OAS2)
```

## Relationship to OpenAPI Versions

The API Model is designed to support both OpenAPI 2.0 and 3.x:

| Concept | OAS2 | OAS3 | API Model |
|---------|------|------|-----------|
| Body parameters | `in: body` | `requestBody` | `RequestBody` |
| Server info | `host`, `basePath`, `schemes` | `servers` | Both attributes on `API` |
| Content types | `consumes`, `produces` | `content` | Both patterns supported |
| Nullable | Not supported | `nullable` | `Schema.nullable` |
| References | `#/definitions/` | `#/components/schemas/` | `Node.ref` |

Exporters handle the translation to version-specific formats.

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall system architecture
- [INTROSPECTORS.md](INTROSPECTORS.md) - Schema extraction from entities
- [EXPORTERS.md](EXPORTERS.md) - OpenAPI format generation
