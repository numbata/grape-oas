# frozen_string_literal: true

module GrapeOAS
  module Exporter
    module Concerns
      module EnumNormalizer
        private

        def normalize_enum(enum_values, type, preserve_nil: false)
          return nil unless enum_values.is_a?(Array)

          base_type = base_type_for(type)
          normalized = enum_values.each_with_object([]) do |value, values|
            next if value.nil?

            normalized_value = case base_type
                               when Constants::SchemaTypes::INTEGER then value.to_i if value.respond_to?(:to_i)
                               when Constants::SchemaTypes::NUMBER then value.to_f if value.respond_to?(:to_f)
                               else value
                               end
            values << normalized_value unless normalized_value.nil?
          end

          normalized.uniq!
          normalized << nil if preserve_nil && enum_values.include?(nil)
          normalized unless normalized.empty?
        end

        def base_type_for(type)
          type.is_a?(Array) ? (type - [Constants::SchemaTypes::NULL]).first : type
        end
      end
    end
  end
end
