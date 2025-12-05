# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Builds OpenAPI schemas from Dry types.
      class TypeSchemaBuilder
        include ApiModelBuilders::Concerns::TypeResolver

        # Re-export ConstraintSet for external use
        ConstraintSet = ConstraintExtractor::ConstraintSet

        def initialize
          # Stateless builder - no initialization needed
        end

        # Builds a schema for a Dry type.
        #
        # @param dry_type [Object] the Dry type
        # @param constraints [ConstraintSet, nil] extracted constraints
        # @return [ApiModel::Schema] the built schema
        def build_schema_for_type(dry_type, constraints = nil)
          constraints ||= ConstraintSet.new(unhandled_predicates: [])
          meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}

          # Check for Sum type first (TypeA | TypeB) -> anyOf
          return build_any_of_schema(dry_type) if TypeUnwrapper.sum_type?(dry_type)

          # Check for Hash schema type (nested schemas like .hash(SomeSchema))
          return build_hash_schema(dry_type) if hash_schema_type?(dry_type)

          primitive, member = TypeUnwrapper.derive_primitive_and_member(dry_type)
          enum_vals = extract_enum_from_type(dry_type)

          schema = build_base_schema(primitive, member)
          schema.nullable = true if nullable?(dry_type, constraints)
          schema.enum = enum_vals if enum_vals
          schema.enum = constraints.enum if constraints.enum && schema.enum.nil?

          apply_constraints(schema, constraints, meta)
          schema
        end

        # Checks if a type is required.
        #
        # @param dry_type [Object] the Dry type
        # @param constraints [ConstraintSet, nil] extracted constraints
        # @return [Boolean] true if required
        def required?(dry_type, constraints = nil)
          # prefer rule-derived info if present
          return constraints.required if constraints && !constraints.required.nil?

          meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
          return false if dry_type.respond_to?(:optional?) && dry_type.optional?
          return false if meta[:omittable]

          true
        end

        private

        def build_any_of_schema(sum_type)
          types = TypeUnwrapper.extract_sum_types(sum_type)

          any_of_schemas = types.map do |t|
            build_schema_for_sum_member(t)
          end

          ApiModel::Schema.new(any_of: any_of_schemas)
        end

        def build_schema_for_sum_member(dry_type)
          # Handle Hash schemas (Types::Hash.schema(...))
          return build_hash_schema(dry_type) if hash_schema_type?(dry_type)

          # Fall back to regular type handling
          build_schema_for_type(dry_type)
        end

        def hash_schema_type?(dry_type)
          return true if dry_type.respond_to?(:keys) && dry_type.keys.any?

          # Check for wrapped types
          unwrapped = TypeUnwrapper.unwrap(dry_type)
          unwrapped.respond_to?(:keys) && unwrapped.keys.any?
        end

        def build_hash_schema(dry_type)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          unwrapped = TypeUnwrapper.unwrap(dry_type)

          return schema unless unwrapped.respond_to?(:keys)

          # Dry::Schema keys method returns an array of Key objects, not a Hash
          schema_keys = unwrapped.keys
          schema_keys.each do |key|
            key_name = key.respond_to?(:name) ? key.name.to_s : key.to_s
            key_type = key.respond_to?(:type) ? key.type : nil

            prop_schema = key_type ? build_schema_for_type(key_type) : default_string_schema
            req = key.respond_to?(:required?) ? key.required? : true
            schema.add_property(key_name, prop_schema, required: req)
          end

          schema
        end

        def build_base_schema(primitive, member)
          if primitive == Array
            items_schema = member ? build_schema_for_type(member) : default_string_schema
            ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: items_schema)
          else
            build_schema_for_primitive(primitive)
          end
        end

        def apply_constraints(schema, constraints, meta)
          applier = ConstraintApplier.new(schema, constraints, meta)
          applier.apply_meta
          applier.apply_rule_constraints
        end

        def nullable?(dry_type, constraints)
          meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}
          return true if dry_type.respond_to?(:optional?) && dry_type.optional?
          return true if meta[:maybe]
          return true if constraints&.nullable

          false
        end

        def extract_enum_from_type(dry_type)
          return unless dry_type.respond_to?(:values)

          vals = dry_type.values
          vals if vals.is_a?(Array)
        rescue NoMethodError
          nil
        end
      end
    end
  end
end
