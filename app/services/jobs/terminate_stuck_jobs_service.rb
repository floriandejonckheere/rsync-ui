# frozen_string_literal: true

module Jobs
  class TerminateStuckJobsService < ApplicationService
    def call
      threshold = Configuration.get("jobs.stuck_threshold").to_i.seconds.ago

      # Terminate pending job runs
      JobRun.pending.where(created_at: ...threshold).find_each do |job_run|
        job_run.error!(error_class: "Stuck", error_message: "Job was not picked up by a worker within the grace period")
      end

      # Terminate running and canceling job runs
      (JobRun.running + JobRun.canceling).each do |job_run|
        next unless stuck?(job_run, threshold)

        if job_run.canceling?
          # SIGTERM presumably worked; the executor never finalized.
          job_run.finish_cancel!
        else
          job_run.error!(error_class: "Stuck", error_message: "Worker process is no longer alive")
        end
      end
    end

    private

    def stuck?(job_run, threshold)
      if job_run.pid.present?
        dead?(job_run.pid)
      else
        # No pid recorded — either between phases or executor died before
        # spawning. Wait for the grace window so we don't reap a healthy row
        # during a brief pid-gap.
        job_run.updated_at < threshold
      end
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
