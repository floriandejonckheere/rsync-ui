# frozen_string_literal: true

module JobRuns
  class PurgeService < ApplicationService
    def call
      threshold = Configuration.get("job_runs.retention").to_i.days.ago

      Rails.logger.info { "Purging job runs started before #{threshold.iso8601}" }

      JobRun
        .where(started_at: ...threshold)
        .find_each(&:destroy!)
    end
  end
end
