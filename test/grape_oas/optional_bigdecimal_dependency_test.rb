# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

module GrapeOAS
  class OptionalBigDecimalDependencyTest < Minitest::Test
    def test_grape_oas_loads_when_bigdecimal_is_unavailable
      root = File.expand_path("../..", __dir__)
      script = <<~RUBY
        module Kernel
          alias __orig_require__ require
          def require(path)
            raise LoadError, "simulated missing bigdecimal" if path == "bigdecimal"
            __orig_require__(path)
          end
        end

        load "lib/grape_oas/constants.rb"
        load "lib/grape_oas/api_model_builders/concerns/type_resolver.rb"

        module GrapeOAS
          module ApiModelBuilders
            module Concerns
              module OasUtilities; end
            end
          end
        end

        load "lib/grape_oas/api_model_builders/request.rb"

        puts "ok"
      RUBY

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        "-e",
        script,
        chdir: root,
      )

      assert status.success?, "expected success, got:\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
      assert_includes stdout, "ok"
    end

    def test_bigdecimal_class_maps_to_number_even_if_loaded_after_constants
      root = File.expand_path("../..", __dir__)
      script = <<~RUBY
        module Kernel
          alias __orig_require__ require
          $block_bigdecimal = true
          def require(path)
            raise LoadError, "blocked bigdecimal" if path == "bigdecimal" && $block_bigdecimal
            __orig_require__(path)
          end
        end

        load "lib/grape_oas/constants.rb"
        load "lib/grape_oas/api_model_builders/concerns/type_resolver.rb"

        resolver = Object.new
        resolver.extend(GrapeOAS::ApiModelBuilders::Concerns::TypeResolver)

        $block_bigdecimal = false
        require "bigdecimal"

        puts resolver.resolve_schema_type(BigDecimal)
      RUBY

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        "-e",
        script,
        chdir: root,
      )

      assert status.success?, "expected success, got:\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
      assert_equal "number", stdout.strip
    end
  end
end
