# frozen_string_literal: true

module JobRuns
  class PurgeJob < ApplicationJob
    limits_concurrency to: 1,
                       key: "purge_job_runs_job",
                       duration: 15.minutes

    def perform
      JobRuns::PurgeService.call
    end
  end
end
