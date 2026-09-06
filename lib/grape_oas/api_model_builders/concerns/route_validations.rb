# frozen_string_literal: true

module GrapeOAS
  module ApiModelBuilders
    module Concerns
      module RouteValidations
        private

        # Grape 3.x snapshots validators on `inheritable_setting.route[:saved_validations]`.
        # Grape 4.0 renamed that to `#route_validations` / `route[:validations]` (grape#2811).
        def grape_route_validations(setting)
          if setting.respond_to?(:route_validations)
            validations = setting.route_validations
            return validations if validations.is_a?(Array)
          end
          return unless setting.respond_to?(:route)

          route_store = setting.route
          return unless route_store.is_a?(Hash)

          route_store[:saved_validations] || route_store[:validations]
        end
      end
    end
  end
end
