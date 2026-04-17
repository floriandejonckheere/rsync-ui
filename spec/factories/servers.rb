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
  end
end
