# frozen_string_literal: true

module Jobs
  class ScheduleJobsService < ApplicationService
    def call
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
  end
end
