# frozen_string_literal: true

require "open3"
require "timeout"

module Notifications
  class NotificationService < ApplicationService
    attr_reader :notification,
                :timeout

    def initialize(notification, timeout: default_timeout)
      super()

      @notification = notification
      @timeout = timeout
    end

    protected

    def default_timeout
      30
    end

    def call_apprise(...)
      stdout, stderr, status = Timeout.timeout(timeout) do
        Open3.capture3("apprise", ...)
      end

      { stdout:, stderr:, status: }
    rescue Timeout::Error => e
      { error: "Timeout after #{timeout}s: #{e.message}" }
    end
  end
end
