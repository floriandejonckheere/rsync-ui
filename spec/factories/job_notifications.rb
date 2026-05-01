# frozen_string_literal: true

FactoryBot.define do
  factory :job_notification do
    job
    notification
  end
end
