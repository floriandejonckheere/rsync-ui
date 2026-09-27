# frozen_string_literal: true

# Localhost is allowed for the Capybara server and the headless browser in system specs
WebMock.disable_net_connect!(allow_localhost: true, allow: ENV.fetch("WEBMOCK_ALLOW_HOST", "localhost"))
