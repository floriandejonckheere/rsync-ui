# frozen_string_literal: true

FactoryBot.define do
  factory :hook do
    job
    hook_type { "pre" }
    command { "/usr/local/bin/backup.sh" }
    arguments { nil }
    enabled { true }

    trait :pre do
      hook_type { "pre" }
    end

    trait :post do
      hook_type { "post" }
    end

    trait :success do
      hook_type { "success" }
    end

    trait :failure do
      hook_type { "failure" }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
