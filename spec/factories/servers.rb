# frozen_string_literal: true

FactoryBot.define do
  factory :server do
    user

    name { FFaker::Internet.domain_word.capitalize }
    host { FFaker::Internet.domain_name }
    port { 22 }
    username { FFaker::Internet.user_name }
    password { FFaker::Internet.password }

    trait :with_password do
      password { FFaker::Internet.password }
      ssh_key { nil }
    end

    trait :with_ssh_key do
      password { nil }
      ssh_key { Rails.root.join("spec/support/fixtures/ssh_key").read }
    end

    trait :with_resource_usage do
      after(:create) do |server|
        create(:resource_usage, server:)
      end
    end

    trait :online do
      probed_at { Time.current }
      last_seen_at { Time.current }
      error_class { nil }
      error_message { nil }
    end

    trait :offline do
      probed_at { 5.minutes.ago }
      last_seen_at { nil }
      error_class { "Net::SSH::AuthenticationFailed" }
      error_message { "Authentication failed for user@example.com" }
    end
  end
end
