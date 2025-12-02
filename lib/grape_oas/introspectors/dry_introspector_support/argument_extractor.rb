# frozen_string_literal: true

module GrapeOAS
  module Introspectors
    module DryIntrospectorSupport
      # Extracts typed values from Dry::Schema AST argument nodes.
      module ArgumentExtractor
        module_function

        def extract_numeric(arg)
          return arg if arg.is_a?(Numeric)
          return arg[1] if arg.is_a?(Array) && arg.size == 2 && arg.first == :num

          nil
        end

        def extract_range(arg)
          return arg if arg.is_a?(Range)
          return arg[1] if arg.is_a?(Array) && arg.first == :range

          nil
        end

        def extract_list(arg)
          return arg[1] if arg.is_a?(Array) && %i[list set].include?(arg.first)
          return arg if arg.is_a?(Array)

          nil
        end

        def extract_literal(arg)
          return arg unless arg.is_a?(Array)
          return arg[1] if arg.length == 2 && %i[value val literal class left right].include?(arg.first)
          return extract_literal(arg.first) if arg.first.is_a?(Array)

          arg
        end

        def extract_pattern(arg)
          return arg.source if arg.is_a?(Regexp)
          return arg[1].source if arg.is_a?(Array) && arg.first == :regexp && arg[1].is_a?(Regexp)
          return arg[1] if arg.is_a?(Array) && arg.first == :regexp && arg[1].is_a?(String)
          return arg[1].source if arg.is_a?(Array) && arg.first == :regex && arg[1].is_a?(Regexp)
          return arg[1] if arg.is_a?(Array) && arg.first == :regex && arg[1].is_a?(String)

          nil
        end
      end
    end
  end
end
