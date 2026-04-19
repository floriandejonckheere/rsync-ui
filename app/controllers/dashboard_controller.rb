# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :dashboard

    @servers = current_user
      .servers
      .includes(:resource_usage)
      .order(:name)
  end
end
