# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Parameter
        def initialize(operation, ref_tracker = nil, nullable_keyword: true)
          @op = operation
          @ref_tracker = ref_tracker
          @nullable_keyword = nullable_keyword
        end

        def build
          Array(@op.parameters).map do |param|
            {
              "name" => param.name,
              "in" => param.location,
              "required" => param.required,
              "description" => param.description,
              "schema" => Schema.new(param.schema, @ref_tracker, nullable_keyword: @nullable_keyword).build
            }.compact
          end.presence
        end
      end
    end
  end
end
