# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  layout :layout_by_action

  def new
    redirect_to root_path
  end

  def create
    redirect_to root_path
  end

  private

  def update_resource(resource, params)
    resource.update_without_password(params)
  end

  def layout_by_action
    case action_name
    when "edit", "update"
      "application"
    else
      "devise"
    end
  end
end
