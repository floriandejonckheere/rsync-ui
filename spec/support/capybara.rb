# frozen_string_literal: true

require "capybara/cuprite"

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :cuprite,
              screen_size: [1600, 1200],
              options: {
                # Set HEADLESS=false to watch the browser (not available inside Docker)
                headless: ENV.fetch("HEADLESS", "true") != "false",
                # Chromium's sandbox is unavailable in unprivileged containers
                browser_options: { "no-sandbox" => nil },
                process_timeout: 20,
                timeout: 10,
              }
  end
end
