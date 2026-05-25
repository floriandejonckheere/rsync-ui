# frozen_string_literal: true

module Jobs
  class TerminateStuckJobsService < ApplicationService
    def call
      threshold = Configuration.get("jobs.stuck_threshold").to_i.seconds.ago

      message = "Job was interrupted (no heartbeat received for over #{Configuration.get('jobs.stuck_threshold')} seconds)"

      stuck_running = JobRun.running.where(
        "last_heartbeat_at < :threshold OR (last_heartbeat_at IS NULL AND started_at < :threshold)",
        threshold:,
      )

      stuck_pending = JobRun
        .pending
        .where(created_at: ...threshold)

      (stuck_running + stuck_pending).each do |job_run|
        job_run.update!(
          status: "errored",
          completed_at: Time.zone.now,
          error_message: message,
        )

        next unless Configuration.get("notifications")

        job_run.job.job_notifications.find_each do |job_notification|
          Notifications::SendJob
            .set(wait: 5.seconds)
            .perform_later(job_notification.id, job_run.id, "failure")
        end
      end
    end
  end
end
