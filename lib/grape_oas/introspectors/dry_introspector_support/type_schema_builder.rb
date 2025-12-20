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
          @path_stack = []
          @constraints_by_path = nil
          @required_by_object_path = nil
        end

        def configure_path_aware_mode(constraints_by_path, required_by_object_path)
          @path_stack = []
          @constraints_by_path = constraints_by_path
          @required_by_object_path = required_by_object_path
        end

        def with_path(part)
          @path_stack << part
          yield
        ensure
          @path_stack.pop
        end

        def current_object_path
          @path_stack.join("/")
        end

        def constraints_for_current_path
          return nil unless @constraints_by_path

          @constraints_by_path[current_object_path]
        end

        def required_keys_for_current_object
          return nil unless @required_by_object_path

          # In path-aware mode we rely entirely on rule-index requiredness
          @required_by_object_path[current_object_path] || []
        end

        # Builds a schema for a Dry type.
        #
        # @param dry_type [Object] the Dry type
        # @param constraints [ConstraintSet, nil] extracted constraints
        # @return [ApiModel::Schema] the built schema
        def build_schema_for_type(dry_type, constraints = nil)
          constraints ||= constraints_for_current_path || ConstraintSet.new(unhandled_predicates: [])
          meta = dry_type.respond_to?(:meta) ? dry_type.meta : {}

          # Check for Sum type first (TypeA | TypeB) -> anyOf
          return build_any_of_schema(dry_type) if TypeUnwrapper.sum_type?(dry_type)

          # Check for Hash schema type (nested schemas like .hash(SomeSchema))
          return build_hash_schema(dry_type) if hash_schema_type?(dry_type)

          # Check for object schema (unwrapped hash with keys)
          unwrapped = TypeUnwrapper.unwrap(dry_type)
          return build_object_schema(unwrapped) if unwrapped.respond_to?(:keys)

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

        def build_object_schema(unwrapped_schema_type)
          schema = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          required_keys = required_keys_for_current_object

          # Dry::Types::Schema does not have each_key, so we disable the cop here
          unwrapped_schema_type.keys.each do |key| # rubocop:disable Style/HashEachMethods
            key_name = key.respond_to?(:name) ? key.name.to_s : key.to_s
            key_type = key.respond_to?(:type) ? key.type : nil

            prop_schema = nil
            with_path(key_name) do
              prop_schema = if key_type
                              build_schema_for_type(key_type, constraints_for_current_path)
                            else
                              default_string_schema
                            end
            end

            is_required = if required_keys
                            required_keys.include?(key_name)
                          else
                            key.respond_to?(:required?) ? key.required? : false
                          end

            schema.add_property(key_name, prop_schema, required: is_required)
          end

          schema
        end

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
          unwrapped = TypeUnwrapper.unwrap(dry_type)

          # Delegate to the same path-aware logic as regular object schemas.
          # This ensures nested rule constraints (e.g. max_size?, gteq?, format?) are applied
          # to properties inside `.hash do ... end` blocks.
          return ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT) unless unwrapped.respond_to?(:keys)

          build_object_schema(unwrapped)
        end

        def build_base_schema(primitive, member)
          if primitive == Array
            items_schema = nil

            with_path("[]") do
              if member
                unwrapped = TypeUnwrapper.unwrap(member)
                items_schema = if unwrapped.respond_to?(:keys)
                                 build_object_schema(unwrapped)
                               else
                                 build_schema_for_type(member, constraints_for_current_path)
                               end
              else
                items_schema = default_string_schema
              end
            end

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
