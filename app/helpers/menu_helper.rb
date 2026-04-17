# frozen_string_literal: true

module MenuHelper
  def menu_item_active?(controller_param, current_controller_name)
    current_controller_name.in?(Array(controller_param))
  end
end
