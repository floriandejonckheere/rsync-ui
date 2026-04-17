# frozen_string_literal: true

module WithConfiguration
  def with_configuration(overrides)
    around do |example|
      originals = {}

      overrides.each do |key, value|
        originals[key] = Configuration.get(key)

        Configuration.set(key, value)
      end

      example.run

      originals.each do |key, value|
        Configuration.set(key, value)
      end
    end
  end
end

RSpec.configure do |config|
  config.extend WithConfiguration
end
