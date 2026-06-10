# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Parameter
        def initialize(operation, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD,
                       array_use_braces: false)
          @op = operation
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
          @array_use_braces = array_use_braces
        end

        def build
          Array(@op.parameters).map do |param|
            schema_hash = Schema.new(param.schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
            schema_description = schema_hash.delete("description")
            description = param.description || schema_description
            {
              "name" => Base::ArrayBraces.param_name(param, enabled: @array_use_braces),
              "in" => param.location,
              "required" => param.required,
              "description" => description,
              "style" => param.style,
              "explode" => param.explode,
              "schema" => schema_hash
            }.compact
          end.presence
        end
      end
    end
  end
end
