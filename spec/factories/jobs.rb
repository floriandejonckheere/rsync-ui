# frozen_string_literal: true

FactoryBot.define do
  factory :job do
    user
    name { FFaker::Lorem.words(2).join(" ").titleize }
    description { nil }
    schedule { nil }
    enabled { true }

    source_repository { association(:repository, user:) }
    destination_repository { association(:repository, user:) }
  end
end
