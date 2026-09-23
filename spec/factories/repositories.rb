# frozen_string_literal: true

FactoryBot.define do
  factory :repository do
    user

    name { FFaker::Lorem.word.capitalize }
    description { nil }
    repository_type { "local" }
    path { "/data/#{FFaker::Lorem.word}" }
    read_only { false }

    trait :local do
      repository_type { "local" }
      server { nil }
    end

    trait :remote do
      repository_type { "remote" }
      server
    end
  end
end
