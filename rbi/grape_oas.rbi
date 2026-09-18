# typed: true
# frozen_string_literal: true

module GrapeOAS
  class << self
    sig { returns(String) }
    def version; end

    sig { returns(T.untyped) }
    def schema_ref_name; end

    sig { params(value: T.untyped).returns(T.untyped) }
    def schema_ref_name=(value); end

    sig { returns(T.untyped) }
    def logger; end

    sig { params(value: T.untyped).returns(T.untyped) }
    def logger=(value); end

    sig { returns(GrapeOAS::Introspectors::Registry) }
    def introspectors; end

    sig { returns(GrapeOAS::Exporter::Registry) }
    def exporters; end

    sig { returns(GrapeOAS::TypeResolvers::Registry) }
    def type_resolvers; end

    sig do
      params(
        app: T.class_of(Grape::API::Instance),
        schema_type: Symbol,
        options: T.untyped,
      ).returns(T::Hash[String, T.untyped])
    end
    def generate(app:, schema_type: :oas3, **options); end
  end

  module DocumentationExtension
    sig do
      params(
        hide_documentation_path: T::Boolean,
        options: T.untyped,
      ).void
    end
    def add_oas_documentation(hide_documentation_path: true, **options); end

    sig { params(options: T.untyped).void }
    def add_swagger_documentation(**options); end
  end

  module Exporter
    class << self
      sig { params(schema_type: Symbol).returns(T.untyped) }
      def for(schema_type); end
    end

    class Registry
      sig { void }
      def initialize; end

      sig do
        params(
          exporter_class: T.untyped,
          as: T.any(Symbol, T::Array[Symbol]),
        ).returns(GrapeOAS::Exporter::Registry)
      end
      def register(exporter_class, as:); end

      sig do
        params(
          schema_types: T.any(Symbol, T::Array[Symbol]),
        ).returns(GrapeOAS::Exporter::Registry)
      end
      def unregister(*schema_types); end

      sig { params(schema_type: Symbol).returns(T.untyped) }
      def for(schema_type); end

      sig { params(schema_type: Symbol).returns(T::Boolean) }
      def registered?(schema_type); end

      sig { returns(T::Array[Symbol]) }
      def schema_types; end

      sig { returns(Integer) }
      def size; end

      sig { returns(GrapeOAS::Exporter::Registry) }
      def clear; end
    end
  end

  module Introspectors
    class Registry
      sig { void }
      def initialize; end

      sig do
        params(
          introspector: T.untyped,
          before: T.untyped,
          after: T.untyped,
        ).returns(GrapeOAS::Introspectors::Registry)
      end
      def register(introspector, before: nil, after: nil); end

      sig do
        params(introspector: T.untyped)
          .returns(GrapeOAS::Introspectors::Registry)
      end
      def unregister(introspector); end

      sig { params(subject: T.untyped).returns(T.untyped) }
      def find(subject); end

      sig do
        params(
          subject: T.untyped,
          stack: T::Array[T.untyped],
          registry: T::Hash[T.untyped, T.untyped],
        ).returns(T.nilable(GrapeOAS::ApiModel::Schema))
      end
      def build_schema(subject, stack: [], registry: {}); end

      sig { params(subject: T.untyped).returns(T::Boolean) }
      def handles?(subject); end

      sig do
        params(
          block: T.nilable(T.proc.params(introspector: T.untyped).void),
        ).returns(T.untyped)
      end
      def each(&block); end

      sig { returns(Integer) }
      def size; end

      sig { returns(GrapeOAS::Introspectors::Registry) }
      def clear; end

      sig { returns(T::Array[T.untyped]) }
      def to_a; end
    end
  end

  module TypeResolvers
    class Registry
      sig { void }
      def initialize; end

      sig do
        params(
          resolver: T.untyped,
          before: T.untyped,
          after: T.untyped,
        ).returns(GrapeOAS::TypeResolvers::Registry)
      end
      def register(resolver, before: nil, after: nil); end

      sig do
        params(resolver: T.untyped)
          .returns(GrapeOAS::TypeResolvers::Registry)
      end
      def unregister(resolver); end

      sig do
        params(type: T.untyped).returns(GrapeOAS::ApiModel::Schema)
      end
      def build_schema(type); end

      sig { params(type: T.untyped).returns(T::Boolean) }
      def registered_resolver_for?(type); end

      sig { params(type: T.untyped).returns(T::Boolean) }
      def handles?(type); end

      sig do
        params(
          block: T.nilable(T.proc.params(resolver: T.untyped).void),
        ).returns(T.untyped)
      end
      def each(&block); end

      sig { returns(Integer) }
      def size; end

      sig { returns(GrapeOAS::TypeResolvers::Registry) }
      def clear; end

      sig { returns(T::Array[T.untyped]) }
      def to_a; end
    end
  end
end

class Grape::API::Instance
  extend GrapeOAS::DocumentationExtension
end
