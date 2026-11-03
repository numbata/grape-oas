# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityIntrospectorDeprecatedTest < Minitest::Test
      class AddressEntity < Grape::Entity
        expose :city, documentation: { type: String }
      end

      INLINE_COPY_DOCS = {
        example: { city: "Paris" },
        values: %w[a b],
        additional_properties: false,
        unevaluated_properties: false,
        defs: { "x" => { "type" => "string" } },
        "$defs": { "x" => { "type" => "string" } }
      }.freeze

      def property_for(doc)
        entity = Class.new(Grape::Entity)
        entity.expose :home, using: AddressEntity, documentation: doc
        EntityIntrospector.new(entity).build_schema.properties.fetch("home")
      end

      def test_deprecated_reference_is_wrapped_and_shared_component_stays_clean
        property = property_for({ deprecated: true, desc: "Old" })
        component = property.all_of.first

        assert property.deprecated
        assert_equal "Old", property.description
        assert_equal "AddressEntity", component.canonical_name.split("::").last
        refute component.deprecated
        assert_nil component.description
      end

      INLINE_COPY_DOCS.each do |key, value|
        define_method(:"test_deprecated_reference_with_#{key.to_s.delete("$")}_is_an_inline_copy") do
          property = property_for({ deprecated: true, key => value })

          assert property.deprecated
          assert_nil property.canonical_name
          assert_nil property.all_of
          assert_equal "object", property.type
        end
      end

      def test_non_deprecated_reference_is_not_copied
        property = property_for({ example: { city: "Paris" } })

        assert_nil property.deprecated
      end
    end
  end
end
