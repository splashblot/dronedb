# coding: utf-8

class Admin::UserDevicesController < Admin::AdminController
  before_filter :login_required

  layout 'application'

  def index
    @first_time    = !current_user.dashboard_viewed?
    @just_logged_in = !!flash['logged']
    current_user.view_dashboard

    respond_to do |format|
      format.html { render 'index', layout: 'application' }
    end

  end
end
