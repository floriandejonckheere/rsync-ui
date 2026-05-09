# frozen_string_literal: true

module Jobs
  class ExecuteJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(job_run, **) { job_run.job_id },
                       duration: 1.hour

    def perform(job_run)
      Jobs::ExecuteService
        .new(job_run)
        .call
    end
  end
end
