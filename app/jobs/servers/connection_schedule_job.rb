# frozen_string_literal: true

module Servers
  class ConnectionScheduleJob < ApplicationJob
    def perform
      return unless Configuration.get("connectivity")

      interval = Configuration.get("connectivity.interval").to_i.minutes

      Server
        .where(probed_at: [nil, ..interval.ago])
        .find_each { |server| ConnectionJob.perform_later(server) }
    end
  end
end
