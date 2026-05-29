# frozen_string_literal: true

module Servers
  class MeasureResourceUsageTask < ApplicationTask
    def call
      Server.find_each { |server| ResourceUsageService.call(server) }
    end
  end
end
