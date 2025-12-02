# frozen_string_literal: true

require "securerandom"

module GrapeOAS
  module ApiModel
    # Base class for all DTO (intermediate) nodes used in OpenAPI v2/v3 conversion.
    # Provides a unique ID and helper methods for referencing and bucketing.
    # All DTO classes for OpenAPIv2 and OpenAPIv3 inherit from Node.
    #
    # @abstract
    # @see GrapeOAS::ApiModel::Schema, GrapeOAS::ApiModel::Parameter, etc.
    class Node
      # OpenAPI component bucket names per spec (some are irregular plurals)
      BUCKET_NAMES = {
        "Schema" => "schemas",
        "Parameter" => "parameters",
        "RequestBody" => "requestBodies",
        "Response" => "responses",
        "Header" => "headers",
        "SecurityScheme" => "securitySchemes",
        "Link" => "links",
        "Callback" => "callbacks",
        "Example" => "examples",
        "PathItem" => "pathItems"
      }.freeze

      class << self
        # Returns the pluralized bucket name for this class (e.g., "schemas", "parameters").
        # Uses OpenAPI spec-compliant names for irregular plurals (e.g., "requestBodies").
        # Memoized at the class level to avoid repeated string manipulation.
        def bucket
          @bucket ||= begin
            class_name = name.split("::").last
            BUCKET_NAMES.fetch(class_name, "#{class_name.downcase}s")
          end
        end
      end

      attr_reader :id

      def initialize(node_id: nil)
        @id = node_id || generate_id
      end

      def ref
        "#/components/#{self.class.bucket}/#{id}"
      end

      private

      def generate_id
        SecureRandom.uuid
      end
    end
  end
end
