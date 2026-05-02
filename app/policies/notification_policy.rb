# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def show?
    user.admin? || record.user == user
  end

  def create?
    user.admin? || record.user == user
  end

  def edit?
    user.admin? || record.user == user
  end

  def update?
    user.admin? || record.user == user
  end

  def destroy?
    update?
  end

  def test?
    update?
  end
end
