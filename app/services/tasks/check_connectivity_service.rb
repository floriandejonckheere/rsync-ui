# frozen_string_literal: true

module Tasks
  class CheckConnectivityService < ApplicationService
    def call
      Server.find_each { |server| Servers::ConnectionService.call(server) }
    end
  end
end
