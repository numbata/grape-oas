# frozen_string_literal: true

module GrapeOAS
  module ApiModel
    # Base class for all DTO (intermediate) nodes used in OpenAPI v2/v3 conversion.
    # Provides a unique ID and helper methods for referencing and bucketing.
    # All DTO classes for OpenAPIv2 and OpenAPIv3 inherit from Node.
    #
    # @abstract
    # @see GrapeOAS::ApiModel::Schema, GrapeOAS::ApiModel::Parameter, etc.
    class Node
      @id_counter = 0

      class << self
        attr_writer :id_counter

        def id_counter
          @id_counter ||= 0
        end

        def next_id
          self.id_counter += 1
        end
      end

      attr_reader :id

      def initialize(node_id: nil)
        @id = node_id || generate_id
      end

      def ref
        "#/components/#{self.class.bucket}/#{id}"
      end

      def self.bucket
        "#{name.split("::").last.downcase}s"
      end

      private

      def generate_id
        "#{self.class.name.split("::").last}_#{self.class.next_id}"
      end
    end
  end
end
