# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Merges duplicate-key nesting exposure branches into a single schema,
      # preserving properties from all branches.
      class NestingMerger
        MAX_MERGE_DEPTH = 10 # Grape nesting rarely exceeds 3-4 levels

        # @param accum [ApiModel::Schema, nil] accumulated schema from previous branches
        # @param current [ApiModel::Schema] schema from the current branch
        # @param depth [Integer] current recursion depth (guarded by MAX_MERGE_DEPTH)
        # @return [ApiModel::Schema] merged schema
        def merge(accum, current, depth = 0)
          return current unless accum
          return accum if current.equal?(accum)

          # Unwrap array schemas to merge their items, then re-wrap
          if array_of_objects?(accum) && array_of_objects?(current)
            merged_items = merge(accum.items, current.items, depth + 1)
            return ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: merged_items)
          end

          return accum unless current&.type == Constants::SchemaTypes::OBJECT
          return current unless accum.type == Constants::SchemaTypes::OBJECT

          merge_object_schemas(accum, current, depth)
        end

        private

        def merge_object_schemas(accum, current, depth)
          shared_required = accum.required & current.required
          merged = ApiModel::Schema.new(type: Constants::SchemaTypes::OBJECT)
          copy_branch_metadata(merged, accum)
          copy_branch_metadata(merged, current)

          accum.properties.each do |n, s|
            merged.add_property(n, s, required: shared_required.include?(n))
          end

          current.properties.each do |n, s|
            existing = merged.properties[n]
            if existing && mergeable_schemas?(existing, s)
              if depth < MAX_MERGE_DEPTH
                merged.properties[n] = merge(existing, s, depth + 1)
              else
                GrapeOAS.logger.warn(
                  "Maximum nesting merge depth (#{MAX_MERGE_DEPTH}) exceeded " \
                  "for property '#{n}'; skipping deep merge",
                )
                merged.add_property(n, s, required: shared_required.include?(n))
              end
            else
              merged.add_property(n, s, required: shared_required.include?(n))
            end
          end
          merged
        end

        # Copies scalar metadata. First non-nil wins for most fields;
        # nullable uses OR (any nullable branch makes the result nullable).
        def copy_branch_metadata(merged, source)
          merged.description ||= source.description
          merged.nullable = true if source.nullable
          merged.format ||= source.format
          merged.examples ||= source.examples if source.respond_to?(:examples)
          return unless source.respond_to?(:extensions) && source.extensions

          existing = merged.extensions || {}
          merged.extensions = existing.merge(deep_dup_hash(source.extensions))
        end

        def mergeable_schemas?(left, right)
          return true if left.type == Constants::SchemaTypes::OBJECT && right.type == Constants::SchemaTypes::OBJECT

          array_of_objects?(left) && array_of_objects?(right)
        end

        def array_of_objects?(schema)
          schema&.type == Constants::SchemaTypes::ARRAY &&
            schema.items&.type == Constants::SchemaTypes::OBJECT
        end

        # Recursive dup for extension hashes. Scalars are shared (safe for frozen literals).
        def deep_dup_hash(hash)
          hash.each_with_object({}) do |(k, v), result|
            result[k] = case v
                        when Hash then deep_dup_hash(v)
                        when Array then v.map { |e| e.is_a?(Hash) ? deep_dup_hash(e) : e }
                        else v
                        end
          end
        end
      end
    end
  end
end
