# Introspectors

Introspectors are responsible for extracting OpenAPI schemas from Ruby classes that define response or request structures. Grape::OAS includes built-in introspectors for `Grape::Entity` and `Dry::Validation::Contract`, and provides a registry for adding custom introspectors.

## Built-in Introspectors

### EntityIntrospector

Extracts schemas from [Grape::Entity](https://github.com/ruby-grape/grape-entity) classes.

```ruby
class UserEntity < Grape::Entity
  expose :id, documentation: { type: Integer, desc: "User ID" }
  expose :name, documentation: { type: String }
  expose :email, documentation: { type: String, format: "email" }
  expose :roles, documentation: { type: String, is_array: true }
end
```

Supported documentation options:
- `type` - Ruby class or OpenAPI type string
- `desc` / `description` - Field description
- `format` - OpenAPI format (email, date-time, uuid, etc.)
- `is_array` - Wrap type in array
- `nullable` - Allow null values
- `example` - Example value
- `enum` / `values` - Allowed values
- `minimum`, `maximum` - Numeric constraints
- `min_length`, `max_length` - String length constraints
- `pattern` - Regex pattern
- `x-*` - Custom OpenAPI extensions

### DryIntrospector

Extracts schemas from [Dry::Validation::Contract](https://dry-rb.org/gems/dry-validation/) classes.

```ruby
class UserContract < Dry::Validation::Contract
  params do
    required(:email).filled(:string)
    required(:age).filled(:integer, gt?: 0)
    optional(:nickname).maybe(:string)
  end
end
```

Supported Dry types and predicates:
- Primitive types: `string`, `integer`, `float`, `bool`, `date`, `time`
- `filled` / `maybe` - Required vs optional
- `gt?`, `lt?`, `gteq?`, `lteq?` - Numeric constraints
- `min_size?`, `max_size?` - Length constraints
- `format?` - Regex pattern matching
- `included_in?` - Enum values
- Sum types (`|`) - Converted to `anyOf`

## Introspector Registry

The registry manages introspectors and determines which one handles a given subject.

### Accessing the Registry

```ruby
# Get the global registry
registry = GrapeOAS.introspectors

# Check what's registered
registry.to_a  # => [EntityIntrospector, DryIntrospector]
```

### Using the Registry

```ruby
# Find introspector for a subject
introspector = GrapeOAS.introspectors.find(UserEntity)
# => GrapeOAS::Introspectors::EntityIntrospector

# Build schema directly via registry
schema = GrapeOAS.introspectors.build_schema(UserEntity)

# Check if any introspector handles a subject
GrapeOAS.introspectors.handles?(UserEntity)  # => true
GrapeOAS.introspectors.handles?(String)       # => false
```

## Creating Custom Introspectors

To support new schema definition formats, create a class that implements the introspector interface:

```ruby
class MyModelIntrospector
  extend GrapeOAS::Introspectors::Base

  # Check if this introspector can handle the subject
  def self.handles?(subject)
    subject.is_a?(Class) && subject < MyBaseModel
  end

  # Build and return an ApiModel::Schema
  def self.build_schema(subject, stack: [], registry: {})
    schema = GrapeOAS::ApiModel::Schema.new(
      type: "object",
      canonical_name: subject.name
    )

    # Extract properties from your model
    subject.attributes.each do |name, type|
      prop_schema = build_property_schema(type)
      schema.add_property(name, prop_schema, required: true)
    end

    # Cache in registry to handle circular references
    registry[subject] = schema
    schema
  end

  def self.build_property_schema(type)
    # Convert your model's type to OpenAPI schema
    case type
    when :string then GrapeOAS::ApiModel::Schema.new(type: "string")
    when :integer then GrapeOAS::ApiModel::Schema.new(type: "integer")
    # ... handle other types
    end
  end
end
```

### Registering Custom Introspectors

```ruby
# Register at the end (lowest priority)
GrapeOAS.introspectors.register(MyModelIntrospector)

# Register before EntityIntrospector (higher priority)
GrapeOAS.introspectors.register(
  MyModelIntrospector,
  before: GrapeOAS::Introspectors::EntityIntrospector
)

# Register after a specific introspector
GrapeOAS.introspectors.register(
  MyModelIntrospector,
  after: GrapeOAS::Introspectors::DryIntrospector
)
```

### Introspector Interface

Every introspector must implement these class methods:

| Method | Description |
|--------|-------------|
| `handles?(subject)` | Returns `true` if this introspector can process the subject |
| `build_schema(subject, stack:, registry:)` | Builds and returns an `ApiModel::Schema` |

Parameters for `build_schema`:
- `subject` - The class/object to introspect
- `stack` - Array for cycle detection (push current class, pop when done)
- `registry` - Hash cache for already-built schemas (prevents infinite recursion)

## Handling Circular References

When entities reference each other, use the `stack` and `registry` parameters:

```ruby
def self.build_schema(subject, stack: [], registry: {})
  # Return cached schema if already built
  return registry[subject] if registry[subject]

  # Detect cycles
  if stack.include?(subject)
    # Return a reference schema for circular dependency
    return GrapeOAS::ApiModel::Schema.new(
      canonical_name: subject.name
    )
  end

  stack.push(subject)
  begin
    schema = GrapeOAS::ApiModel::Schema.new(...)
    registry[subject] = schema

    # Build nested schemas (they'll use the same stack/registry)
    # ...

    schema
  ensure
    stack.pop
  end
end
```

## Third-Party Gems

To create a gem that adds introspector support:

```ruby
# lib/grape_oas_my_model.rb
require 'grape_oas'
require 'grape_oas_my_model/introspector'

# Auto-register on load
GrapeOAS.introspectors.register(GrapeOASMyModel::Introspector)
```

Users just need to add your gem to their Gemfile:

```ruby
gem 'grape-oas'
gem 'grape-oas-my-model'
```
