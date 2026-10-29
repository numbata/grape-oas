# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    class EntityExposureDescriptionScopeTest < Minitest::Test
      class ScopedImage < Grape::Entity
        expose :url, documentation: { type: String }
      end

      class ScopedPage < Grape::Entity
        expose :hero, using: ScopedImage, documentation: { desc: "Hero image" }
        expose :logo, using: ScopedImage, documentation: { desc: "Page logo" }
        expose :gallery, using: ScopedImage, documentation: { desc: "Gallery", is_array: true }
      end

      def test_descriptions_stay_local_to_each_property
        schema = EntityIntrospector.new(ScopedPage).build_schema
        hero = schema.properties["hero"]
        logo = schema.properties["logo"]
        gallery = schema.properties["gallery"]

        assert_equal "Hero image", hero.description
        assert_equal "Page logo", logo.description
        assert_nil hero.all_of.first.description
        assert_same hero.all_of.first, logo.all_of.first
        assert_equal "Gallery", gallery.description
        assert_nil gallery.items.description
      end
    end
  end
end
