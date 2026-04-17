# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    Configuration.load_paths += [Rails.root.join("spec/support/configurations.yml")]
  end
end
