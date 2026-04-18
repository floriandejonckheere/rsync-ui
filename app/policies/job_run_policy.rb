# frozen_string_literal: true

class JobRunPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def destroy?
    user.admin? || record.user == user
  end

  def cancel?
    user.admin? || record.user == user
  end
end
