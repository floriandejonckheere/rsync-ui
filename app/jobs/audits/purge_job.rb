# frozen_string_literal: true

module Audits
  class PurgeJob < ApplicationJob
    limits_concurrency to: 1,
                       key: "purge_audits_job",
                       duration: 15.minutes

    def perform
      Audits::PurgeService.call
    end
  end
end
