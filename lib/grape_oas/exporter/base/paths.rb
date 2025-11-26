# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module Base
      # Base class for Paths exporters
      # Contains common logic shared between OAS2 and OAS3
      class Paths
        def initialize(source, ref_tracker = nil, **options)
          @source = source
          @ref_tracker = ref_tracker
          @options = options
        end

        def build
          if api?(@source)
            build_paths(@source)
          else
            build_path_item(@source)
          end
        end

        private

        def api?(obj)
          obj.respond_to?(:paths)
        end

        def build_paths(api)
          paths = {}
          api.paths.each do |path|
            paths[path.template] = build_path_item(path)
          end
          paths
        end

        def build_path_item(path)
          item = {}
          path.operations.each do |op|
            item[op.http_method] = build_operation(op)
          end
          item
        end

        # Template method - subclasses must implement
        # Returns the version-specific Operation instance
        def build_operation(op)
          raise NotImplementedError, "#{self.class} must implement #build_operation"
        end
      end
    end
  end
end
