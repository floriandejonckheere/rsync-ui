# frozen_string_literal: true

module Notifications
  class ExportService < ::ExportService
    private

    def headers = ["name", "description", "url", "enabled", "user_email"]

    def rows
      Notification.all.map do |notification|
        [
          notification.name,
          notification.description,
          notification.url,
          notification.enabled,
          notification.user.email,
        ]
      end
    end
  end
end
