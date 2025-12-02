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
        processor.new(nil).send(:apply_rule_constraints, schema, constraints)

        assert_equal Integer, schema.extensions["x-typePredicate"]
      end

      def test_min_max_predicates_map_to_bounds
        ast = [:and, [
          [:predicate, [:min?, [[:num, 2], [:input, nil]]]],
          [:predicate, [:max?, [[:num, 5], [:input, nil]]]]
        ]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        processor.new(nil).send(:apply_rule_constraints, schema, constraints)

        assert_equal 2, schema.minimum
        assert_equal 5, schema.maximum
      end

      def test_empty_predicate_sets_size_zero
        ast = [:predicate, [:empty?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "array")
        processor.new(nil).send(:apply_rule_constraints, schema, constraints)

        assert_equal 0, schema.min_items
        assert_equal 0, schema.max_items
      end

      def test_parity_predicates_recorded
        ast = [:predicate, [:odd?, [[:input, nil]]]]
        constraints = constraint_extractor.new(nil).send(:walk_ast, ast)
        schema = GrapeOAS::ApiModel::Schema.new(type: "integer")
        processor.new(nil).send(:apply_rule_constraints, schema, constraints)

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

        processor.new(nil).send(:apply_rule_constraints, num_schema, mult_constraints)
        processor.new(nil).send(:apply_rule_constraints, str_schema, bytes_constraints)
        processor.new(nil).send(:apply_rule_constraints, bool_schema, true_constraints)
        bool_schema = GrapeOAS::ApiModel::Schema.new(type: "boolean")
        processor.new(nil).send(:apply_rule_constraints, bool_schema, false_constraints)

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

        processor.new(nil).send(:apply_rule_constraints, uuid_schema, uuid_constraints)
        processor.new(nil).send(:apply_rule_constraints, email_schema, email_constraints)
        processor.new(nil).send(:apply_rule_constraints, date_schema, date_constraints)
        processor.new(nil).send(:apply_rule_constraints, datetime_schema, datetime_constraints)
        processor.new(nil).send(:apply_rule_constraints, bool_schema, bool_constraints)

        assert_equal "uuid", uuid_schema.format
        assert_equal "email", email_schema.format
        assert_equal "date", date_schema.format
        assert_equal "date-time", datetime_schema.format
        assert_equal :boolean, bool_schema.extensions["x-typePredicate"]
      end

      def test_pattern_from_format_predicate
        contract = Dry::Schema.Params do
          required(:slug).filled(:string, format?: /\A[a-z0-9\-]+\z/)
        end

        schema = processor.build(contract)
        slug = schema.properties["slug"]

        assert_equal "\\A[a-z0-9\\-]+\\z", slug.pattern
      end
    end
  end
end
