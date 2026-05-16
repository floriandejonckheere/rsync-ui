# frozen_string_literal: true

module Servers
  class ResourceUsageJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(server, **) { server.id },
                       duration: 5.minutes

    def perform(server, force: false)
      interval = Configuration.get("resource_usage.interval").to_i.minutes

      return if server&.resource_usage&.probed_at && server.resource_usage.probed_at > interval.ago && !force

      ResourceUsageService.call(server)
    end
  end
end
