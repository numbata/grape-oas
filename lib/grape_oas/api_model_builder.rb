# frozen_string_literal: true

module GrapeOAS
  class ApiModelBuilder
    attr_reader :api

    def initialize
      @api = GrapeOAS::ApiModel::API.new(
        title: "Grape API",
        version: "1",
      )

      @apis = []
    end

    def add_app(app)
      GrapeOAS::ApiModelBuilders::Path
        .new(api: @api, routes: app.routes)
        .build
    end
  end
end
