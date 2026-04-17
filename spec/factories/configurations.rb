# frozen_string_literal: true

FactoryBot.define do
  factory :configuration do
    key { "test.key" }
    value { "value" }
  end
end
