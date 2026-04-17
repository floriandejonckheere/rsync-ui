# frozen_string_literal: true

module AlertHelper
  def alert_class_for(type)
    case type.to_sym
    when :notice
      "alert alert-info"
    when :success
      "alert alert-success"
    when :alert, :error
      "alert alert-destructive"
    when :warning
      "alert alert-warning"
    else # rubocop:disable Lint/DuplicateBranch
      "alert alert-info"
    end
  end

  def icon_name_for(type)
    case type.to_sym
    when :success
      "circle-check"
    when :alert, :error
      "circle-x"
    when :warning
      "triangle-alert"
    else
      "info"
    end
  end
end
