# frozen_string_literal: true

require "securerandom"

module GrapeOAS
  module ApiModel
    # Base class for all Intermediate Language (IL) nodes used in OpenAPI v2/v3 conversion.
    # Provides a unique ID and helper methods for referencing and bucketing.
    # All IL classes for OpenAPIv2 and OpenAPIv3 inherit from Node.
    #
    # @abstract
    # @see GrapeOAS::ApiModel::Schema, GrapeOAS::ApiModel::Parameter, etc.
    class Node
      attr_reader :id

      def initialize(id: nil)
        @id = id || SecureRandom.uuid
      end

      def self.attr_rw(*names)
        names.each { |n| attr_accessor n }
      end

      def ref
        "#/components/#{self.class.bucket}/#{id}"
      end

      def self.bucket
        "#{name.split("::").last.downcase}s"
      end
    end
  end
end
