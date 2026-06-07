# frozen_string_literal: true

module JobRuns
  class TerminateStuckService < ApplicationService
    def call
      threshold = Configuration.get("jobs.stuck_threshold").to_i.seconds.ago

      Rails.logger.info { "Terminating all job runs stuck since #{threshold.iso8601}" }

      # Terminate pending job runs
      JobRun.pending.where(created_at: ...threshold).find_each do |job_run|
        Rails.logger.info { "Terminating stuck job run #{job_run.id} (still pending after grace period)" }

        job_run.error!(error_class: "Stuck", error_message: "Job was not picked up by a worker within the grace period")
      end

      # Terminate running and canceling job runs
      (JobRun.running + JobRun.canceling).each do |job_run|
        next unless stuck?(job_run, threshold)

        Rails.logger.info { "Terminating #{job_run.status} stuck job run #{job_run.id} (dead)" }

        if job_run.canceling?
          # SIGTERM presumably worked, the job run was never completed
          job_run.cancel!
        else
          job_run.error!(error_class: "Stuck", error_message: "Worker process is no longer alive")
        end
      end
    end

    private

    def stuck?(job_run, threshold)
      return dead?(job_run.pid) if job_run.pid.present?

      # No pid recorded: either between hooks/rsync or executor died before spawning
      # Wait for the grace window, so a healthy process isn't reaped between hooks/rsync
      job_run.updated_at < threshold
    end

    def dead?(pid)
      Process.kill(0, -pid)

      false
    rescue Errno::ESRCH
      true
    rescue Errno::EPERM
      false
    end
  end
end
