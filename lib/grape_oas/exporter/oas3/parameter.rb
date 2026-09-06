# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module OAS3
      class Parameter
        def initialize(operation, ref_tracker = nil, nullable_strategy: Constants::NullableStrategy::KEYWORD,
                       schema_builder: Schema)
          @op = operation
          @ref_tracker = ref_tracker
          @nullable_strategy = nullable_strategy
          @schema_builder = schema_builder
        end

        def build
          Array(@op.parameters).map do |param|
            schema_hash = @schema_builder.new(param.schema, @ref_tracker, nullable_strategy: @nullable_strategy).build
            schema_description = schema_hash.delete("description")
            description = param.description || schema_description
            {
              "name" => param.name,
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
