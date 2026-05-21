# frozen_string_literal: true

FactoryBot.define do
  factory :audit do
    server
    command { "echo ok" }
    category { "connectivity" }
    output { "ok\n" }
    exit_status { 0 }
    started_at { Time.current }
    completed_at { Time.current }
  end
end
