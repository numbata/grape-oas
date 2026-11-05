# frozen_string_literal: true

require "test_helper"

module GrapeOAS
  module ApiModelBuilders
    class RequestParamsDeprecatedTest < Minitest::Test
      def deprecated_names(api_class)
        api = GrapeOAS::ApiModel::API.new(title: "Test API", version: "1.0")
        _, params = RequestParams.new(api: api, route: api_class.routes.first).build
        params.select(&:deprecated).map(&:name).sort
      end

      def test_only_descendants_of_a_deprecated_middle_ancestor_inherit_the_flag
        api_class = Class.new(Grape::API) do
          params do
            optional :filter, type: Hash do
              optional :name, type: String
              optional :geo, type: Hash, documentation: { deprecated: true } do
                optional :lat, type: String
              end
            end
          end
          get("/items") { {} }
        end

        assert_equal ["filter[geo][lat]"], deprecated_names(api_class).grep(/lat/)
        refute_includes deprecated_names(api_class), "filter[name]"
      end

      def test_sibling_sharing_a_name_prefix_does_not_inherit_the_flag
        api_class = Class.new(Grape::API) do
          params do
            optional :filter, type: Hash, documentation: { deprecated: true } do
              optional :a, type: String
            end
            optional :filter_extra, type: Hash do
              optional :b, type: String
            end
          end
          get("/items") { {} }
        end

        assert_equal ["filter[a]"], deprecated_names(api_class)
      end
    end
  end
end
