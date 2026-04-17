# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  authorize :user

  def create?
    true
  end

  def update?
    user.admin? || user == record
  end

  def destroy?
    user.admin? || user == record
  end
end
