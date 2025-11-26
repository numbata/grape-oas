# frozen_string_literal: true

require "test_helper"
require "ostruct"

module GrapeOAS
  module Exporter
    module Base
      class PathsTest < Minitest::Test
        def test_build_delegates_to_build_paths_when_api
          api = mock_api_with_paths
          paths = TestPathsImplementation.new(api, nil)

          result = paths.build

          assert_kind_of Hash, result
          assert_includes result.keys, "/users"
        end

        def test_build_delegates_to_build_path_item_when_path
          path = mock_path_with_operations
          paths = TestPathsImplementation.new(path, nil)

          result = paths.build

          assert_kind_of Hash, result
          assert_includes result.keys, :get
        end

        def test_build_paths_iterates_all_paths
          api = mock_api_with_multiple_paths
          paths = TestPathsImplementation.new(api, nil)

          result = paths.build

          assert_equal 2, result.size
          assert_includes result.keys, "/users"
          assert_includes result.keys, "/posts"
        end

        def test_build_path_item_creates_operation_for_each_http_method
          path = mock_path_with_multiple_operations
          paths = TestPathsImplementation.new(path, nil)

          result = paths.build

          assert_equal 2, result.size
          assert_includes result.keys, :get
          assert_includes result.keys, :post
        end

        def test_passes_ref_tracker_to_subclass
          api = mock_api_with_paths
          ref_tracker = Set.new
          paths = TestPathsImplementation.new(api, ref_tracker)

          paths.build

          assert_equal ref_tracker, paths.last_ref_tracker
        end

        def test_passes_options_to_subclass
          api = mock_api_with_paths
          paths = TestPathsImplementation.new(api, nil, custom_option: "value")

          paths.build

          assert_equal({ custom_option: "value" }, paths.last_options)
        end

        def test_raises_not_implemented_error_without_subclass_override
          api = mock_api_with_paths
          paths = Paths.new(api, nil)

          error = assert_raises(NotImplementedError) do
            paths.build
          end

          assert_match(/must implement #build_operation/, error.message)
        end

        private

        def mock_api_with_paths
          path = mock_path_with_operations
          OpenStruct.new(
            paths: [path],
          )
        end

        def mock_api_with_multiple_paths
          path1 = OpenStruct.new(
            template: "/users",
            operations: [mock_operation(:get)],
          )
          path2 = OpenStruct.new(
            template: "/posts",
            operations: [mock_operation(:get)],
          )
          OpenStruct.new(
            paths: [path1, path2],
          )
        end

        def mock_path_with_operations
          OpenStruct.new(
            template: "/users",
            operations: [mock_operation(:get)],
          )
        end

        def mock_path_with_multiple_operations
          OpenStruct.new(
            template: "/users",
            operations: [mock_operation(:get), mock_operation(:post)],
          )
        end

        def mock_operation(http_method)
          OpenStruct.new(http_method: http_method)
        end

        # Test implementation of Base::Paths for testing
        class TestPathsImplementation < Paths
          attr_reader :last_ref_tracker, :last_options

          def build_operation(op)
            @last_ref_tracker = @ref_tracker
            @last_options = @options
            { operation_id: "test_#{op.http_method}" }
          end
        end
      end
    end
  end
end
