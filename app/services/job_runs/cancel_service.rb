# frozen_string_literal: true

module JobRuns
  class CancelService < ApplicationService
    attr_reader :job_run

    def initialize(job_run)
      super()

      @job_run = job_run
    end

    def call
      return { success: false } unless job_run.cancelable?

      enqueue_cancel_job = false

      job_run.with_lock do
        job_run.reload

        return { success: false } unless job_run.cancelable?

        # pending -> canceled (immediate) ; running -> canceling (needs SIGTERM)
        enqueue_cancel_job = job_run.running?

        job_run.cancel!
      end

      JobRuns::CancelJob.perform_later(job_run) if enqueue_cancel_job

      { success: true }
    end
  end
end
