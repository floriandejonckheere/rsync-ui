# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    user

    categorizable_type { "Job" }
    sequence(:name) { |n| "Category #{n}" }
  end
end
