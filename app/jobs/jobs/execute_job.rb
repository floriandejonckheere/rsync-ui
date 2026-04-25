# frozen_string_literal: true

module Jobs
  class ExecuteJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(job, **) { job.id },
                       duration: 1.hour

    def perform(job, trigger: "manual")
      Jobs::ExecuteService
        .new(job, trigger:)
        .call
    end
  end
end
