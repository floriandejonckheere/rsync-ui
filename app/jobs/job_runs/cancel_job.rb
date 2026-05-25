# frozen_string_literal: true

module JobRuns
  class CancelJob < ApplicationJob
    queue_as :workers

    def perform(job_run)
      job_run.reload

      return unless job_run.running? || job_run.canceling?

      return if job_run.pid.nil?

      Process.kill("TERM", -job_run.pid)
    rescue Errno::ESRCH, Errno::EPERM
      # Process already gone or unsignalable. The executor's next checkpoint
      # will observe job_run.canceling? and transition to :canceled itself.
      nil
    end
  end
end
