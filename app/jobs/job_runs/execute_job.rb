# frozen_string_literal: true

module JobRuns
  class ExecuteJob < ApplicationJob
    queue_as :workers

    limits_concurrency to: 1,
                       key: ->(job_run, **) { job_run.job_id },
                       duration: 1.hour

    def perform(job_run)
      ExecuteService
        .new(job_run)
        .call
    end
  end
end
