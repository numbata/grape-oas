# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Extracts typed values from Dry::Schema AST argument nodes.
      module ArgumentExtractor
        module_function

        # AST node tags for collection predicates (included_in?, excluded_from?)
        LIST_TAGS = %i[list set].freeze
        # AST node tags for literal value wrappers
        LITERAL_TAGS = %i[value val literal class left right].freeze
        # AST node tags for regex patterns
        PATTERN_TAGS = %i[regexp regex].freeze
        # @see Constants::MAX_ENUM_RANGE_SIZE
        MAX_ENUM_RANGE_SIZE = Constants::MAX_ENUM_RANGE_SIZE

        def extract_numeric(arg)
          return arg if arg.is_a?(Numeric)
          return arg[1] if arg.is_a?(Array) && arg.size == 2 && arg.first == :num

          nil
        end

        def extract_range(arg)
          return arg if arg.is_a?(Range)
          return arg[1] if arg.is_a?(Array) && arg.first == :range
          return arg[1] if arg.is_a?(Array) && arg.first == :size && arg[1].is_a?(Range)
          # Handle [:list, range] from included_in? predicates
          return arg[1] if list_node?(arg) && arg[1].is_a?(Range)

          nil
        end

        def extract_list(arg)
          if list_node?(arg)
            inner = arg[1]
            # For non-numeric ranges (e.g., 'a'..'z'), expand to array
            # Numeric ranges should use min/max constraints instead
            return range_to_enum_array(inner) if inner.is_a?(Range)

            return inner
          end
          return arg if arg.is_a?(Array)
          return range_to_enum_array(arg) if arg.is_a?(Range)

          nil
        end

        # Converts a non-numeric bounded Range to an array for enum values.
        # Delegates to Constants.expand_range_to_enum for shared logic.
        def range_to_enum_array(range)
          Constants.expand_range_to_enum(range)
        end

        def extract_literal(arg)
          return arg unless arg.is_a?(Array)
          return arg[1] if arg.length == 2 && LITERAL_TAGS.include?(arg.first)
          return extract_literal(arg.first) if arg.first.is_a?(Array)

          arg
        end

        def extract_pattern(arg)
          return arg.source if arg.is_a?(Regexp)

          if arg.is_a?(Array) && PATTERN_TAGS.include?(arg.first)
            return arg[1].source if arg[1].is_a?(Regexp)
            return arg[1] if arg[1].is_a?(String)
          end

          nil
        end

        # Helper to check if arg is a list/set AST node
        def list_node?(arg)
          arg.is_a?(Array) && LIST_TAGS.include?(arg.first)
        end
      end
    end
  end
end
