# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user

    name { FFaker::Internet.domain_word.capitalize }
    description { nil }
    url { "json://#{FFaker::Internet.domain_name}/webhook" }
    enabled { true }
  end
end
