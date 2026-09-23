# frozen_string_literal: true

class CategoryPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def update?
    user.admin? || record.user == user
  end
end
