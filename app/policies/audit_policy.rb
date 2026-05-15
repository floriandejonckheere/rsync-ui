# frozen_string_literal: true

class AuditPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    relation
  end

  def index?
    user.admin?
  end

  def show?
    user.admin?
  end
end
