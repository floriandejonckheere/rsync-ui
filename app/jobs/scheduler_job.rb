# frozen_string_literal: true

class SchedulerJob < ApplicationJob
  def perform
    schedule_jobs
    schedule_connectivity
    schedule_resource_usage
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

      Jobs::ExecuteJob.perform_later(job, trigger: "scheduled")
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
end
