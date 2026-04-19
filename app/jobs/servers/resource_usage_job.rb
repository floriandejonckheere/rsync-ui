# frozen_string_literal: true

module Servers
  class ResourceUsageJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(server, **) { server.id },
                       duration: 5.minutes

    def perform(server)
      ResourceUsageService.call(server)
    end
  end
end
