# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      # Merges duplicate-key nesting exposure branches into a single schema,
      # preserving properties from all branches.
      module NestingMerger
        MAX_MERGE_DEPTH = 10 # Grape nesting rarely exceeds 3-4 levels

        class << self
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
              merged_array = ApiModel::Schema.new(type: Constants::SchemaTypes::ARRAY, items: merged_items)
              copy_branch_metadata(merged_array, accum)
              copy_branch_metadata(merged_array, current)
              return merged_array
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
                    "NestingMerger: property '#{n}' exceeds maximum merge depth " \
                    "(#{MAX_MERGE_DEPTH}); using current branch value instead of merging",
                  )
                  merged.add_property(n, s, required: shared_required.include?(n))
                end
              else
                merged.add_property(n, s, required: shared_required.include?(n))
              end
            end
            merged
          end

          # Copies scalar metadata. First non-nil wins for description/format/examples;
          # nullable uses OR; extensions are merged (last branch wins for overlapping keys).
          def copy_branch_metadata(merged, source)
            merged.description ||= source.description
            merged.nullable = true if source.nullable
            merged.format ||= source.format
            merged.examples ||= source.examples if source.respond_to?(:examples)
            return unless source.respond_to?(:extensions) && source.extensions

            existing = merged.extensions || {}
            merged.extensions = existing.merge(dup_hash_recursive(source.extensions))
          end

          def mergeable_schemas?(left, right)
            return true if left.type == Constants::SchemaTypes::OBJECT && right.type == Constants::SchemaTypes::OBJECT

            array_of_objects?(left) && array_of_objects?(right)
          end

          def array_of_objects?(schema)
            schema&.type == Constants::SchemaTypes::ARRAY &&
              schema.items&.type == Constants::SchemaTypes::OBJECT
          end

          # Recursive dup for extension hashes. Non-collection values are shared (safe for frozen literals).
          def dup_hash_recursive(hash)
            hash.each_with_object({}) do |(k, v), result|
              result[k] = case v
                          when Hash then dup_hash_recursive(v)
                          when Array then v.map { |e| e.is_a?(Hash) ? dup_hash_recursive(e) : e }
                          else v
                          end
            end
          end
        end
      end
    end
  end
end
