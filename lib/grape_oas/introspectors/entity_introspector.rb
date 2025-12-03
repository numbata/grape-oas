# frozen_string_literal: true

require_relative "../api_model_builders/concerns/type_resolver"
require_relative "entity_introspector_support/cycle_tracker"
require_relative "entity_introspector_support/discriminator_handler"
require_relative "entity_introspector_support/inheritance_builder"
require_relative "entity_introspector_support/property_extractor"
require_relative "entity_introspector_support/exposure_processor"

module GrapeOAS
  module Introspectors
    class EntityIntrospector
      include GrapeOAS::ApiModelBuilders::Concerns::TypeResolver
      include GrapeOAS::ApiModelBuilders::Concerns::OasUtilities

      def initialize(entity_class, stack: [], registry: {})
        @entity_class = entity_class
        @stack = stack
        @registry = registry
      end

      def build_schema
        return cached_schema if cached_schema_available?
        return build_inherited_schema if inherits_with_discriminator?

        schema = initialize_or_reuse_schema
        return cycle_tracker.handle_cycle(schema) if cycle_tracker.cyclic_reference?

        cycle_tracker.with_tracking { populate_schema(schema) }
      end

      private

      def cached_schema_available?
        built = @registry[@entity_class]
        built && !built.properties.empty?
      end

      def cached_schema
        @registry[@entity_class]
      end

      def initialize_or_reuse_schema
        @registry[@entity_class] ||= ApiModel::Schema.new(
          type: Constants::SchemaTypes::OBJECT,
          canonical_name: @entity_class.name,
          description: nil,
          nullable: nil,
        )
      end

      def populate_schema(schema)
        doc = entity_doc
        apply_schema_metadata(schema, doc)
        exposure_processor.add_exposures_to_schema(schema)
        schema
      end

      def apply_schema_metadata(schema, doc)
        schema.description ||= EntityIntrospectorSupport::PropertyExtractor.extract_description(doc)
        schema.nullable = EntityIntrospectorSupport::PropertyExtractor.extract_nullable(doc) if schema.nullable.nil?
        EntityIntrospectorSupport::PropertyExtractor.apply_entity_level_properties(schema, doc)
        apply_extensions(schema, doc)
        discriminator_handler.apply(schema)
      end

      def apply_extensions(schema, doc)
        root_ext = extract_extensions(doc)
        schema.extensions = root_ext if root_ext
      end

      def entity_doc
        @entity_class.respond_to?(:documentation) ? (@entity_class.documentation || {}) : {}
      rescue NoMethodError
        {}
      end

      def inherits_with_discriminator?
        EntityIntrospectorSupport::InheritanceBuilder.inherits_with_discriminator?(@entity_class)
      end

      def build_inherited_schema
        parent = EntityIntrospectorSupport::InheritanceBuilder.find_parent_entity(@entity_class)
        inheritance_builder.build_inherited_schema(parent)
      end

      def cycle_tracker
        @cycle_tracker ||= EntityIntrospectorSupport::CycleTracker.new(@entity_class, @stack)
      end

      def discriminator_handler
        @discriminator_handler ||= EntityIntrospectorSupport::DiscriminatorHandler.new(@entity_class)
      end

      def exposure_processor
        @exposure_processor ||= EntityIntrospectorSupport::ExposureProcessor.new(
          @entity_class,
          stack: @stack,
          registry: @registry,
        )
      end

      def inheritance_builder
        @inheritance_builder ||= EntityIntrospectorSupport::InheritanceBuilder.new(
          @entity_class,
          stack: @stack,
          registry: @registry,
        )
      end
    end
  end
end
