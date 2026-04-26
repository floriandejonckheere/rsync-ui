# frozen_string_literal: true

module Servers
  class ResourceUsageScheduleJob < ApplicationJob
    def perform
      return unless Configuration.get("resource_usage")

      interval = Configuration.get("resource_usage.interval").to_i.minutes

      Server
        .left_joins(:resource_usage)
        .where(resource_usages: { probed_at: [nil, ..interval.ago] })
        .find_each { |server| ResourceUsageJob.perform_later(server) }
    end
  end
end
