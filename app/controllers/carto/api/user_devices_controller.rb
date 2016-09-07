# encoding: utf-8
require_dependency 'carto/uuidhelper'

module Carto
  module Api
    class UserDevicesController < ::Api::ApplicationController
      include Carto::ControllerHelper

      ssl_required :update
      before_filter :load_user_devicess, only: [:update]

      rescue_from StandardError, with: :rescue_from_standard_error
      rescue_from Carto::LoadError, with: :rescue_from_carto_error

      def update
        category = params[:category].to_sym
        @devices.devices[category] = params[:notifications]
        if @devices.save
          render_jsonp({ devices: @devices.devices[category] }, 200)
        else
          render_jsonp({ errors: @devices.errors.to_h }, 422)
        end
      end

      private

      def load_user_devices
        @devices = Carto::User.find(current_user.id).devices
      end
    end
  end
end
