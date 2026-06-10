# frozen_string_literal: true

class SchedulerJob < ApplicationJob
  limits_concurrency to: 1,
                     key: "scheduler_job",
                     duration: 30.seconds

  def perform
    terminate_stuck_job_runs

    schedule_jobs
    schedule_connectivity
    schedule_resource_usage
    schedule_disk_size
  end

  private

  def terminate_stuck_job_runs
    JobRuns::TerminateStuckService.call
  end

  def schedule_jobs
    return unless Configuration.get("scheduler")

    Jobs::ScheduleJobsService.call
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

  def schedule_disk_size
    return unless Configuration.get("disk_size")

    interval = Configuration.get("disk_size.interval").to_i.minutes

    Repository
      .where(disk_size_measured_at: [nil, ..interval.ago])
      .find_each { |repository| Repositories::DiskSizeJob.perform_later(repository) }
  end
end
