# frozen_string_literal: true

module JobNotifications
  class ExportService < ::ExportService
    private

    def headers = ["job_name", "notification_name", "user_email", "enabled", "on_start", "on_success", "on_failure"]

    def rows
      JobNotification.all.map do |jn|
        [
          jn.job.name,
          jn.notification.name,
          jn.notification.user.email,
          jn.enabled,
          jn.on_start,
          jn.on_success,
          jn.on_failure,
        ]
      end
    end
  end
end
