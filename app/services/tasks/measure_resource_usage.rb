# frozen_string_literal: true

module Tasks
  class MeasureResourceUsage < ApplicationService
    def call
      Server.find_each { |server| Servers::ResourceUsageService.call(server) }
    end
  end
end
