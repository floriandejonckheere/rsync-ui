# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  authorize :user

  def run?
    user&.admin?
  end
end
