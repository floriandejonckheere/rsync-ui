# frozen_string_literal: true

module JobNotifications
  class ImportService < ::ImportService
    private

    def csv_filename
      "07_job_notifications.csv"
    end

    def import(row)
      user = User.find_by!(email: row["user_email"])
      job = user.jobs.find_by!(name: row["job_name"])
      notification = user.notifications.find_by!(name: row["notification_name"])

      JobNotification
        .create_with(job_notification_attributes(row))
        .find_or_create_by!(job:, notification:)
    end

    def job_notification_attributes(row)
      {
        enabled: boolean_type.cast(row["enabled"]),
        on_start: boolean_type.cast(row["on_start"]),
        on_success: boolean_type.cast(row["on_success"]),
        on_failure: boolean_type.cast(row["on_failure"]),
      }
    end
  end
end
