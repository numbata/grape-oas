# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module Introspectors
    module EntityIntrospectorSupport
      class ResolveCanonicalNameTest < Minitest::Test
        class PlainEntity < Grape::Entity
          expose :id, documentation: { type: Integer }
        end

        class NamedEntity < Grape::Entity
          expose :id, documentation: { type: Integer }

          def self.entity_name
            "CustomName"
          end
        end

        class NilNameEntity < Grape::Entity
          expose :id, documentation: { type: Integer }

          def self.entity_name
            nil
          end
        end

        class EmptyNameEntity < Grape::Entity
          expose :id, documentation: { type: Integer }

          def self.entity_name
            ""
          end
        end

        class WhitespaceNameEntity < Grape::Entity
          expose :id, documentation: { type: Integer }

          def self.entity_name
            "   "
          end
        end

        class ParentWithName < Grape::Entity
          expose :id, documentation: { type: Integer }

          def self.entity_name
            "Parent"
          end
        end

        class ChildInheritsName < ParentWithName
          expose :extra, documentation: { type: String }
        end

        class ChildOverridesName < ParentWithName
          expose :extra, documentation: { type: String }

          def self.entity_name
            "OverriddenChild"
          end
        end

        module EntityNaming
          def entity_name
            "FromModule"
          end
        end

        class ExtendedEntity < Grape::Entity
          extend EntityNaming

          expose :id, documentation: { type: Integer }
        end

        class ChildInheritsExtend < ExtendedEntity
          expose :extra, documentation: { type: String }
        end

        class ChildOverridesExtend < ExtendedEntity
          expose :extra, documentation: { type: String }

          def self.entity_name
            "ChildOverride"
          end
        end

        def test_uses_class_name_when_no_entity_name
          assert_equal PlainEntity.name,
                       EntityIntrospectorSupport.resolve_canonical_name(PlainEntity)
        end

        def test_uses_entity_name_when_defined
          assert_equal "CustomName",
                       EntityIntrospectorSupport.resolve_canonical_name(NamedEntity)
        end

        def test_falls_back_on_nil_entity_name
          assert_equal NilNameEntity.name,
                       EntityIntrospectorSupport.resolve_canonical_name(NilNameEntity)
        end

        def test_falls_back_on_empty_entity_name
          assert_equal EmptyNameEntity.name,
                       EntityIntrospectorSupport.resolve_canonical_name(EmptyNameEntity)
        end

        def test_falls_back_on_whitespace_only_entity_name
          assert_equal WhitespaceNameEntity.name,
                       EntityIntrospectorSupport.resolve_canonical_name(WhitespaceNameEntity)
        end

        def test_ignores_inherited_entity_name
          assert_equal ChildInheritsName.name,
                       EntityIntrospectorSupport.resolve_canonical_name(ChildInheritsName)
        end

        def test_uses_overridden_entity_name
          assert_equal "OverriddenChild",
                       EntityIntrospectorSupport.resolve_canonical_name(ChildOverridesName)
        end

        def test_uses_entity_name_from_extend
          assert_equal "FromModule",
                       EntityIntrospectorSupport.resolve_canonical_name(ExtendedEntity)
        end

        def test_ignores_inherited_extend_entity_name
          assert_equal ChildInheritsExtend.name,
                       EntityIntrospectorSupport.resolve_canonical_name(ChildInheritsExtend)
        end

        def test_uses_overridden_extend_entity_name
          assert_equal "ChildOverride",
                       EntityIntrospectorSupport.resolve_canonical_name(ChildOverridesExtend)
        end
      end
    end
  end
end
