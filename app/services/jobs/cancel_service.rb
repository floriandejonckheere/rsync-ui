# frozen_string_literal: true

module Jobs
  class CancelService < ApplicationService
    attr_reader :job_run

    def initialize(job_run)
      super()

      @job_run = job_run
    end

    def call
      return { success: false } unless job_run.cancelable?

      job_run.with_lock do
        job_run.reload

        return { success: false } unless job_run.cancelable?

        if job_run.pending?
          job_run.cancel!
        else
          job_run.update!(cancel_requested_at: job_run.cancel_requested_at || Time.current)
        end
      end

      { success: true }
    end
  end
end
