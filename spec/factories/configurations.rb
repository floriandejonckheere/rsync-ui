# frozen_string_literal: true

FactoryBot.define do
  factory :configuration, class: "Configuration::String" do
    type { "Configuration::String" }

    key { "test.key" }
    value { "value" }

    factory :string_configuration, class: "Configuration::String" do
      type { "Configuration::String" }

      value { "value" }
    end

    factory :integer_configuration, class: "Configuration::Integer" do
      type { "Configuration::Integer" }

      value { 123 }
    end

    factory :float_configuration, class: "Configuration::Float" do
      type { "Configuration::Float" }

      value { 123.45 }
    end

    factory :boolean_configuration, class: "Configuration::Boolean" do
      type { "Configuration::Boolean" }

      value { true }
    end
  end
end
