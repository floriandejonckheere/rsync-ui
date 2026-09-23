# frozen_string_literal: true

FactoryBot.define do
  factory :job do
    user
    name { FFaker::Lorem.words(2).join(" ").titleize }
    description { nil }
    schedule { nil }
    enabled { true }

    source_repository { association(:repository, :local, user:) }
    destination_repository { association(:repository, :remote, user:) }

    trait :with_hooks do
      pre_hook { association(:hook, :pre) }
      post_hook { association(:hook, :post) }
      success_hook { association(:hook, :success) }
      failure_hook { association(:hook, :failure) }
    end
  end
end
