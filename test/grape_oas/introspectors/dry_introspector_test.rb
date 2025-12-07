# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class DryIntrospectorTest < Minitest::Test
      def processor
        @processor ||= Introspectors::DryIntrospector
      end

      def constraint_extractor
        @constraint_extractor ||= Introspectors::DryIntrospectorSupport::ConstraintExtractor
      end

      def constraint_applier
        @constraint_applier ||= Introspectors::DryIntrospectorSupport::ConstraintApplier
      end

      def apply_constraints(schema, constraints)
        applier = constraint_applier.new(schema, constraints)
        applier.apply_rule_constraints
      end

      def test_or_branch_intersection_keeps_common_enum
        ast = [:or, [
          [:predicate, [:included_in?, [[:list, %w[a b]], [:input, nil]]]],
          [:predicate, [:included_in?, [[:list, %w[b c]], [:input, nil]]]]
        ]]

        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal %w[b], constraints.enum
      end

      def test_each_array_predicates_apply_to_array_not_items
        contract = Dry::Schema.Params do
          required(:tags).array(:string, min_size?: 1, max_size?: 3)
        end

        schema = processor.build(contract)
        tags = schema.properties["tags"]

        assert_equal "array", tags.type
        assert_equal 1, tags.min_items
        assert_equal 3, tags.max_items
        assert_equal "string", tags.items.type
      end

      def test_excluded_values_and_numeric_bounds
        contract = Dry::Schema.Params do
          required(:score).filled(:integer, excluded_from?: [5], gteq?: 1, lteq?: 10)
        end

        schema = processor.build(contract)
        score = schema.properties["score"]

        assert_equal 1, score.minimum
        assert_equal 10, score.maximum
        assert_equal [5], score.extensions["x-excludedValues"]
        assert_includes schema.required, "score"
      end

      def test_eql_predicate_sets_enum
        contract = Dry::Schema.Params do
          required(:kind).filled(:string, eql?: "fixed")
        end

        schema = processor.build(contract)
        kind = schema.properties["kind"]

        assert_equal ["fixed"], kind.enum
      end

      def test_type_predicate_recorded
        ast = [:predicate, [:type?, [[:class, Integer], [:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        apply_constraints(schema, constraints)

        assert_equal Integer, schema.extensions["x-typePredicate"]
      end

      def test_min_max_predicates_map_to_bounds
        ast = [:and, [
          [:predicate, [:min?, [[:num, 2], [:input, nil]]]],
          [:predicate, [:max?, [[:num, 5], [:input, nil]]]]
        ]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        apply_constraints(schema, constraints)

        assert_equal 2, schema.minimum
        assert_equal 5, schema.maximum
      end

      def test_empty_predicate_sets_size_zero
        ast = [:predicate, [:empty?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "array")
        apply_constraints(schema, constraints)

        assert_equal 0, schema.min_items
        assert_equal 0, schema.max_items
      end

      def test_parity_predicates_recorded
        ast = [:predicate, [:odd?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        apply_constraints(schema, constraints)

        assert_equal "odd", schema.extensions["x-numberParity"]
      end

      def test_multiple_of_and_bytesize_and_true_false
        ast_mult = [:predicate, [:multiple_of?, [[:num, 5]]]]
        ast_true = [:predicate, [:true?, [[:input, nil]]]]
        ast_false = [:predicate, [:false?, [[:input, nil]]]]
        ast_bytes = [:predicate, [:bytesize?, [[:num, 3], [:num, 8]]]]

        mult_constraints = constraint_extractor.new(nil).send(:walk_ast, ast_mult)
        bytes_constraints = constraint_extractor.new(nil).send(:walk_ast, ast_bytes)
        true_constraints = constraint_extractor.new(nil).send(:walk_ast, ast_true)
        false_constraints = constraint_extractor.new(nil).send(:walk_ast, ast_false)

        num_schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        str_schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        bool_schema = GrapeOAS::ApiModel::Schema.new(type: "boolean")

        apply_constraints(num_schema, mult_constraints)
        apply_constraints(str_schema, bytes_constraints)
        apply_constraints(bool_schema, true_constraints)
        bool_schema = GrapeOAS::ApiModel::Schema.new(type: "boolean")
        apply_constraints(bool_schema, false_constraints)

        assert_equal 5, num_schema.extensions&.fetch("multipleOf")
        assert_equal 3, str_schema.min_length
        assert_equal 8, str_schema.max_length
        assert_equal [false], bool_schema.enum
      end

      def test_uuid_and_email_formats
        uuid_ast = [:predicate, [:uuid?, [[:input, nil]]]]
        email_ast = [:predicate, [:email?, [[:input, nil]]]]
        date_ast = [:predicate, [:date?, [[:input, nil]]]]
        datetime_ast = [:predicate, [:date_time?, [[:input, nil]]]]
        bool_ast = [:predicate, [:bool?, [[:input, nil]]]]

        uuid_constraints = constraint_extractor.new(nil).send(:walk_ast, uuid_ast)
        email_constraints = constraint_extractor.new(nil).send(:walk_ast, email_ast)
        date_constraints = constraint_extractor.new(nil).send(:walk_ast, date_ast)
        datetime_constraints = constraint_extractor.new(nil).send(:walk_ast, datetime_ast)
        bool_constraints = constraint_extractor.new(nil).send(:walk_ast, bool_ast)

        uuid_schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        email_schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        date_schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        datetime_schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        bool_schema = GrapeOAS::ApiModel::Schema.new(type: "boolean")

        apply_constraints(uuid_schema, uuid_constraints)
        apply_constraints(email_schema, email_constraints)
        apply_constraints(date_schema, date_constraints)
        apply_constraints(datetime_schema, datetime_constraints)
        apply_constraints(bool_schema, bool_constraints)

        assert_equal "uuid", uuid_schema.format
        assert_equal "email", email_schema.format
        assert_equal "date", date_schema.format
        assert_equal "date-time", datetime_schema.format
        assert_equal :boolean, bool_schema.extensions["x-typePredicate"]
      end

      def test_pattern_from_format_predicate
        contract = Dry::Schema.Params do
          required(:slug).filled(:string, format?: /\A[a-z0-9-]+\z/)
        end

        schema = processor.build(contract)
        slug = schema.properties["slug"]

        assert_equal "\\A[a-z0-9-]+\\z", slug.pattern
      end

      # Additional tests for branch coverage

      def test_lt_predicate_sets_exclusive_maximum
        ast = [:predicate, [:lt?, [[:num, 100], [:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        apply_constraints(schema, constraints)

        assert_equal 100, schema.maximum
        assert schema.exclusive_maximum
      end

      def test_range_predicate_sets_bounds
        ast = [:predicate, [:range?, [(1..10), [:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        apply_constraints(schema, constraints)

        assert_equal 1, schema.minimum
        assert_equal 10, schema.maximum
      end

      def test_range_predicate_with_exclusive_end
        ast = [:predicate, [:range?, [(1...10), [:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal 1, constraints.minimum
        assert_equal 10, constraints.maximum
        assert constraints.exclusive_maximum
      end

      def test_uri_predicate_sets_format
        ast = [:predicate, [:uri?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal "uri", constraints.format
      end

      def test_even_parity_predicate
        ast = [:predicate, [:even?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        apply_constraints(schema, constraints)

        assert_equal "even", schema.extensions["x-numberParity"]
      end

      def test_min_bytesize_predicate
        ast = [:predicate, [:min_bytesize?, [[:num, 5]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal 5, constraints.min_size
      end

      def test_max_bytesize_predicate
        ast = [:predicate, [:max_bytesize?, [[:num, 20]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal 20, constraints.max_size
      end

      def test_or_branch_with_single_branch
        ast = [:or, [
          [:predicate, [:included_in?, [[:list, %w[a b]], [:input, nil]]]]
        ]]

        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal %w[a b], constraints.enum
      end

      def test_shorthand_predicate_syntax
        # Tests the shorthand predicate format [:symbol, value] instead of [:predicate, [...]]
        ast = [:gteq?, [[:num, 5], [:input, nil]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_equal 5, constraints.minimum
      end

      def test_or_branch_intersects_numeric_bounds
        ast = [:or, [
          [:and, [
            [:predicate, [:gteq?, [[:num, 1], [:input, nil]]]],
            [:predicate, [:lteq?, [[:num, 10], [:input, nil]]]]
          ]],
          [:and, [
            [:predicate, [:gteq?, [[:num, 5], [:input, nil]]]],
            [:predicate, [:lteq?, [[:num, 8], [:input, nil]]]]
          ]]
        ]]

        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        # Intersection: max of mins (5), min of maxes (8)
        assert_equal 5, constraints.minimum
        assert_equal 8, constraints.maximum
      end

      def test_or_branch_with_nullable_false_in_one_branch
        ast = [:or, [
          [:predicate, [:filled?, [[:input, nil]]]],
          [:predicate, [:nil?, [[:input, nil]]]]
        ]]

        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        # When one branch has nullable=false, intersection keeps it false
        refute constraints.nullable
      end

      def test_unhandled_predicate_recorded
        ast = [:predicate, [:unknown_predicate?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        assert_includes constraints.unhandled_predicates, :unknown_predicate?
      end

      def test_argument_extractor_direct_numeric
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        assert_equal 42, extractor.extract_numeric(42)
        assert_in_delta(3.14, extractor.extract_numeric(3.14))
      end

      def test_argument_extractor_direct_range
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_range(1..10)

        assert_equal 1..10, result
      end

      def test_argument_extractor_range_from_ast
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_range([:range, 5..15])

        assert_equal 5..15, result
      end

      def test_argument_extractor_direct_array_list
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_list(%w[a b c])

        assert_equal %w[a b c], result
      end

      def test_argument_extractor_set_list
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_list([:set, %w[x y]])

        assert_equal %w[x y], result
      end

      def test_argument_extractor_direct_regexp_pattern
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_pattern(/\d+/)

        assert_equal "\\d+", result
      end

      def test_argument_extractor_regexp_string_in_ast
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_pattern([:regexp, "\\w+"])

        assert_equal "\\w+", result
      end

      def test_argument_extractor_regex_with_regexp_object
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_pattern([:regex, /[a-z]+/])

        assert_equal "[a-z]+", result
      end

      def test_argument_extractor_regex_with_string
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_pattern([:regex, "[0-9]+"])

        assert_equal "[0-9]+", result
      end

      def test_argument_extractor_literal_nested_array
        extractor = Introspectors::DryIntrospectorSupport::ArgumentExtractor

        result = extractor.extract_literal([[:value, "nested"]])

        assert_equal "nested", result
      end

      def test_constraint_merger_with_nil_source
        merger = Introspectors::DryIntrospectorSupport::ConstraintMerger
        target = constraint_set_class.new(unhandled_predicates: [])

        # Should not raise when source is nil
        merger.merge(target, nil)

        assert_nil target.enum
      end

      def test_constraint_merger_merges_all_fields
        merger = Introspectors::DryIntrospectorSupport::ConstraintMerger
        target = constraint_set_class.new(unhandled_predicates: [])
        source = constraint_set_class.new(
          enum: %w[a b],
          nullable: true,
          pattern: "\\d+",
          format: "email",
          required: true,
          type_predicate: :string,
          parity: :odd,
          min_size: 1,
          max_size: 10,
          minimum: 0,
          maximum: 100,
          exclusive_minimum: true,
          exclusive_maximum: false,
          excluded_values: [5],
          unhandled_predicates: [:custom?],
        )

        merger.merge(target, source)

        assert_equal %w[a b], target.enum
        assert target.nullable
        assert_equal "\\d+", target.pattern
        assert_equal "email", target.format
        assert target.required
        assert_equal :string, target.type_predicate
        assert_equal :odd, target.parity
        assert_equal 1, target.min_size
        assert_equal 10, target.max_size
        assert_equal 0, target.minimum
        assert_equal 100, target.maximum
        assert_equal [5], target.excluded_values
        assert_includes target.unhandled_predicates, :custom?
      end

      def test_apply_meta_for_string_type
        schema = GrapeOAS::ApiModel::Schema.new(type: "string")
        meta = { min_size: 2, max_size: 50, pattern: "\\w+" }
        applier = constraint_applier.new(schema, nil, meta)
        applier.apply_meta

        assert_equal 2, schema.min_length
        assert_equal 50, schema.max_length
        assert_equal "\\w+", schema.pattern
      end

      def test_apply_meta_for_numeric_type_with_gt_lt
        schema = GrapeOAS::ApiModel::Schema.new(type: "number")
        meta = { gt: 0, lt: 100 }
        applier = constraint_applier.new(schema, nil, meta)
        applier.apply_meta

        assert_equal 0, schema.minimum
        assert schema.exclusive_minimum
        assert_equal 100, schema.maximum
        assert schema.exclusive_maximum
      end

      def test_apply_meta_for_array_type
        schema = GrapeOAS::ApiModel::Schema.new(type: "array")
        meta = { min_items: 1, max_items: 5 }
        applier = constraint_applier.new(schema, nil, meta)
        applier.apply_meta

        assert_equal 1, schema.min_items
        assert_equal 5, schema.max_items
      end

      def test_key_node_visits_nested_content
        ast = [:key, [:name, [:predicate, [:filled?, [[:input, nil]]]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        refute constraints.nullable
      end

      def test_implication_node_visits_children
        ast = [:implication, [
          [:predicate, [:key?, [%i[name field]]]],
          [:predicate, [:filled?, [[:input, nil]]]]
        ]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        refute constraints.nullable
      end

      def test_not_node_visits_nested
        ast = [:not, [:predicate, [:nil?, [[:input, nil]]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)

        # The :nil? predicate sets nullable to true
        assert constraints.nullable
      end

      # Tests for Dry::Schema canonical_name and registry caching

      def test_plain_schema_without_schema_name_has_nil_canonical_name
        schema = Dry::Schema.JSON do
          required(:value).filled(:integer)
        end

        result = processor.build_schema(schema)

        assert_nil result.canonical_name
        assert_equal "object", result.type
        assert result.properties.key?("value")
      end

      def test_schema_with_schema_name_method_uses_it_as_canonical_name
        # This tests the behavior when schema_name is added via extension (like user's app does)
        schema = Dry::Schema.JSON do
          required(:name).filled(:string)
        end

        # Simulate a schema_name extension by defining the method
        schema.define_singleton_method(:schema_name) { "MockedSchemaName" }

        result = processor.build_schema(schema)

        assert_equal "MockedSchemaName", result.canonical_name
        assert_equal "object", result.type
        assert result.properties.key?("name")
      end

      def test_schema_with_schema_name_registered_by_name
        schema = Dry::Schema.JSON do
          required(:field).filled(:string)
        end
        schema.define_singleton_method(:schema_name) { "NamedSchema" }

        registry = {}
        processor.build_schema(schema, registry: registry)

        assert registry.key?("NamedSchema")
        assert_equal "string", registry["NamedSchema"].properties["field"].type
      end

      def test_cached_schema_returned_on_second_build
        schema = Dry::Schema.JSON do
          required(:data).filled(:string)
        end
        schema.define_singleton_method(:schema_name) { "CachedSchema" }

        registry = {}
        result1 = processor.build_schema(schema, registry: registry)
        result2 = processor.build_schema(schema, registry: registry)

        assert_same result1, result2, "Second build should return cached schema"
      end

      def test_different_schemas_with_different_names_stored_separately
        schema1 = Dry::Schema.JSON do
          required(:field1).filled(:string)
        end
        schema1.define_singleton_method(:schema_name) { "SchemaOne" }

        schema2 = Dry::Schema.JSON do
          required(:field2).filled(:integer)
        end
        schema2.define_singleton_method(:schema_name) { "SchemaTwo" }

        registry = {}
        result1 = processor.build_schema(schema1, registry: registry)
        result2 = processor.build_schema(schema2, registry: registry)

        assert_equal "SchemaOne", result1.canonical_name
        assert_equal "SchemaTwo", result2.canonical_name
        assert registry.key?("SchemaOne")
        assert registry.key?("SchemaTwo")
        refute_same registry["SchemaOne"], registry["SchemaTwo"]
      end

      def test_schema_with_schema_name_builds_full_properties
        schema = Dry::Schema.JSON do
          required(:id).filled(:integer)
          required(:name).filled(:string, min_size?: 1)
          optional(:description).maybe(:string)
        end
        schema.define_singleton_method(:schema_name) { "DetailedSchema" }

        result = processor.build_schema(schema)

        assert_equal "DetailedSchema", result.canonical_name
        assert_equal 3, result.properties.size
        assert_equal "integer", result.properties["id"].type
        assert_equal "string", result.properties["name"].type
        assert_equal 1, result.properties["name"].min_length
        assert_equal "string", result.properties["description"].type
        assert_includes result.required, "id"
        assert_includes result.required, "name"
        refute_includes result.required, "description"
      end

      # Tests for nested hash schemas (.hash(SomeSchema))

      def test_nested_hash_schema_builds_object_with_properties
        # Define a nested schema
        nested_schema = Dry::Schema.JSON do
          required(:x).filled(:integer)
          required(:y).filled(:integer)
        end

        # Define a parent schema that uses .hash() to reference the nested schema
        parent_schema = Dry::Schema.JSON do
          required(:name).filled(:string)
          required(:position).hash(nested_schema)
        end

        result = processor.build_schema(parent_schema)

        assert_equal "object", result.type
        assert result.properties.key?("name")
        assert result.properties.key?("position")

        # The nested position property should be an object with x and y properties
        position_schema = result.properties["position"]

        assert_equal "object", position_schema.type
        assert position_schema.properties.key?("x")
        assert position_schema.properties.key?("y")
        assert_equal "integer", position_schema.properties["x"].type
        assert_equal "integer", position_schema.properties["y"].type
      end

      def test_nested_hash_schema_with_optional_field
        # NOTE: When using .hash(nested_schema), Dry::Types::Schema keys
        # don't preserve the required/optional distinction from the original schema.
        # The key.required? method returns the key's options[:required] which is
        # set to false for all keys in this context.
        # This is a limitation of Dry::Types, not grape-oas.
        nested_schema = Dry::Schema.JSON do
          required(:width).filled(:integer)
          optional(:height).filled(:integer)
        end

        parent_schema = Dry::Schema.JSON do
          required(:dimensions).hash(nested_schema)
        end

        result = processor.build_schema(parent_schema)
        dimensions = result.properties["dimensions"]

        assert_equal "object", dimensions.type
        assert dimensions.properties.key?("width")
        assert dimensions.properties.key?("height")
        # NOTE: Due to Dry::Types limitation, nested hash keys all report as not required
        # The required array will be empty because key.required? returns false for all
        assert_empty dimensions.required,
                     "Nested hash schema keys report as not required due to Dry::Types limitation"
      end

      def test_deeply_nested_hash_schemas
        innermost = Dry::Schema.JSON do
          required(:value).filled(:string)
        end

        middle = Dry::Schema.JSON do
          required(:inner).hash(innermost)
        end

        outer = Dry::Schema.JSON do
          required(:middle).hash(middle)
        end

        result = processor.build_schema(outer)

        middle_schema = result.properties["middle"]

        assert_equal "object", middle_schema.type

        inner_schema = middle_schema.properties["inner"]

        assert_equal "object", inner_schema.type
        assert inner_schema.properties.key?("value")
        assert_equal "string", inner_schema.properties["value"].type
      end

      def test_optional_nested_hash_schema
        nested_schema = Dry::Schema.JSON do
          required(:field).filled(:string)
        end

        parent_schema = Dry::Schema.JSON do
          required(:name).filled(:string)
          optional(:config).hash(nested_schema)
        end

        result = processor.build_schema(parent_schema)

        assert result.properties.key?("config")
        refute_includes result.required, "config"

        config_schema = result.properties["config"]

        assert_equal "object", config_schema.type
        assert config_schema.properties.key?("field")
      end

      private

      def constraint_set_class
        Introspectors::DryIntrospectorSupport::ConstraintExtractor::ConstraintSet
      end
    end
  end
end
