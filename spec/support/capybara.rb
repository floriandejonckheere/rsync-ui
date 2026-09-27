# frozen_string_literal: true

require "capybara/cuprite"

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :system

  # System specs are slow and need a browser, so they only run when requested explicitly: either by running
  # only system specs (e.g. `rspec spec/system`), or by setting SYSTEM_SPECS=1 (e.g. to run the whole suite).
  # Evaluated lazily, because the files to run are not known yet when the support files are loaded.
  system_dirs = ["spec/system", "spec/screenshots"].map { |dir| Rails.root.join(dir).to_s }
  screenshots_dir = Rails.root.join("spec/screenshots").to_s

  config.filter_run_excluding type: lambda { |type|
    next false unless type == :system
    next false if ENV["SYSTEM_SPECS"].present?

    config.files_to_run.any? { |file| system_dirs.none? { |dir| File.expand_path(file).start_with?(dir) } }
  }

  # Screenshot specs overwrite the README screenshots, so they only run when requested explicitly (e.g. `rspec spec/screenshots`)
  config.filter_run_excluding screenshots: lambda { |screenshots|
    screenshots && config.files_to_run.any? { |file| !File.expand_path(file).start_with?(screenshots_dir) }
  }

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
