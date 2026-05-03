# frozen_string_literal: true

class HookPolicy < ApplicationPolicy
  authorize :user

  def update?
    user.admin? || record.job.user == user
  end

  def destroy?
    user.admin? || record.job.user == user
  end
end
