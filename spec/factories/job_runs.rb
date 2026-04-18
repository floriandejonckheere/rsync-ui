# frozen_string_literal: true

FactoryBot.define do
  factory :job_run do
    job
    user
    trigger { :manual }
    status { :pending }

    trait :pending do
      status { :pending }
      started_at { nil }
      completed_at { nil }
    end

    trait :running do
      status { :running }
      started_at { 5.minutes.ago }
      completed_at { nil }
    end

    trait :completed do
      status { :completed }
      started_at { 10.minutes.ago }
      completed_at { 5.minutes.ago }
    end

    trait :failed do
      status { :failed }
      started_at { 10.minutes.ago }
      completed_at { 5.minutes.ago }
    end

    trait :canceled do
      status { :canceled }
      started_at { nil }
      completed_at { nil }
    end
  end
end
