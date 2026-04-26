# frozen_string_literal: true

module GrapeOAS
  module TypeResolvers
    # Catch-all used by Registry#build_schema when no registered resolver
    # matches. Returns a plain string schema for any type. Not registered
    # in the chain — called automatically by the registry as a built-in
    # fallback.
    class DefaultResolver
      class << self
        def handles?(_type)
          true
        end

        def build_schema(type)
          logger = GrapeOAS.logger
          if logger.respond_to?(:debug)
            logger.debug { "No type resolver matched #{type.inspect}, falling back to string schema" }
          end
          ApiModel::Schema.new(type: Constants::SchemaTypes::STRING)
        end
      end
    end
  end
end
