# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  layout :layout_by_action

  def new
    redirect_to root_path
  end

  def create
    redirect_to root_path
  end

  def destroy
    head :forbidden
  end

  private

  def update_resource(resource, params)
    if params[:password].present?
      resource.update(params.except("current_password"))
    else
      resource.update_without_password(params.except("password", "password_confirmation"))
    end
  end

  def after_update_path_for(_resource)
    root_path
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
