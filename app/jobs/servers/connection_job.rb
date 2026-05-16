# frozen_string_literal: true

module Servers
  class ConnectionJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(server) { server.id },
                       duration: 5.minutes

    def perform(server)
      interval = Configuration.get("connectivity.interval").to_i.minutes

      return if server.probed_at && server.probed_at > interval.ago

      ConnectionService.call(server)
    end
  end
end
