# frozen_string_literal: true

class ConfigurationPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.none
  end

  def index?
    user&.admin?
  end

  def update?
    user&.admin?
  end
end
