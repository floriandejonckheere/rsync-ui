# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  layout :layout_by_action

  private

  def layout_by_action
    case action_name
    when "edit", "update"
      "application"
    else
      "devise"
    end
  end
end
