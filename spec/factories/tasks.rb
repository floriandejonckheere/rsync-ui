# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    sequence(:name) { |n| "task_#{n}" }
    class_name { "DummyTask" }
    status { nil }
    configuration { nil }

    trait :completed do
      status { "completed" }
      last_run_at { 1.hour.ago }
    end

    trait :failed do
      status { "failed" }
      last_run_at { 1.hour.ago }
      error_class { "StandardError" }
      error_message { "Something went wrong" }
    end
  end
end
