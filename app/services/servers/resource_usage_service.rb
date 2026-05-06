# frozen_string_literal: true

module Servers
  class ResourceUsageService < ApplicationService
    attr_reader :server,
                :force

    def initialize(server, force: false)
      super()

      @server = server
      @force = force
    end

    def call
      probed_at = server.resource_usage&.probed_at

      return if probed_at && probed_at > 5.minutes.ago && !force

      server.measure_resource_usage
    end
  end
end
