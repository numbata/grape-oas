# frozen_string_literal: true

require "json"
require "json_schemer"

module OASValidator
  META_PATHS = {
    "2.0" => "test/helpers/oas_metaschemas/oas2.json",
    "3.0" => "test/helpers/oas_metaschemas/oas30.json",
    "3.1" => "test/helpers/oas_metaschemas/oas31.json"
  }.freeze

  def self.meta_for(spec_hash)
    if spec_hash["swagger"] == "2.0"
      META_PATHS["2.0"]
    elsif spec_hash["openapi"]&.start_with?("3.0")
      META_PATHS["3.0"]
    elsif spec_hash["openapi"]&.start_with?("3.1")
      META_PATHS["3.1"]
    end
  end

  def self.validate!(spec_hash)
    meta_path = meta_for(spec_hash)
    raise "Unknown spec version" unless meta_path && File.exist?(meta_path)

    spec = deep_dup(spec_hash)
    spec.delete("$schema")

    schemer = JSONSchemer.schema(
      JSON.parse(File.read(meta_path)),
      ref_resolver: lambda { |uri|
        JSON.parse(File.read("test/helpers/oas_metaschemas/draft4.json")) if uri.to_s.include?("draft-04")
      },
    )
    errors = schemer.validate(spec).to_a

    raise ValidationError, errors unless errors.empty?

    true
  end

  def self.deep_dup(obj)
    case obj
    when Hash
      obj.transform_values { |v| deep_dup(v) }
    when Array
      obj.map { |v| deep_dup(v) }
    else
      obj
    end
  end

  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("OAS validation failed: #{errors.first}")
    end
  end
end
