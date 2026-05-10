# frozen_string_literal: true

class SchedulerJob < ApplicationJob
  limits_concurrency to: 1, key: "scheduler_job", duration: 1.minute

  def perform
    schedule_jobs
    schedule_connectivity
    schedule_resource_usage
    detect_stuck_jobs
  end

  private

  def schedule_jobs
    return unless Configuration.get("scheduler")

    now = Time.zone.now

    Job.where(enabled: true).where.not(schedule: [nil, ""]).find_each do |job|
      cron = Fugit.parse_cron(job.schedule)
      next unless cron

      prev_tick = cron.previous_time(now).to_t
      last_scheduled_run = job.job_runs.scheduled.order(:created_at).last

      next if last_scheduled_run && last_scheduled_run.created_at >= prev_tick

      job_run = job
        .job_runs
        .create!(user: job.user, trigger: "scheduled", status: "pending")

      Jobs::ExecuteJob.perform_later(job_run)
    end
  end

  def schedule_connectivity
    return unless Configuration.get("connectivity")

    interval = Configuration.get("connectivity.interval").to_i.minutes

    Server
      .where(probed_at: [nil, ..interval.ago])
      .find_each { |server| Servers::ConnectionJob.perform_later(server) }
  end

  def schedule_resource_usage
    return unless Configuration.get("resource_usage")

    interval = Configuration.get("resource_usage.interval").to_i.minutes

    Server
      .left_joins(:resource_usage)
      .where(resource_usages: { probed_at: [nil, ..interval.ago] })
      .find_each { |server| Servers::ResourceUsageJob.perform_later(server) }
  end

  def detect_stuck_jobs
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
        error_messages: message,
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
