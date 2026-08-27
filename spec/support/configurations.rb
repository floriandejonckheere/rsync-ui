# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    Configuration.load_paths += [Rails.root.join("spec/support/configurations.yml")]
    I18n.load_path += [Rails.root.join("spec/support/locales/en.yml")]
    I18n.backend.reload!
  end
end
