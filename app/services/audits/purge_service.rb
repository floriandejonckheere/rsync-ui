# frozen_string_literal: true

module Audits
  class PurgeService < ApplicationService
    def call
      threshold = Configuration.get("audits.retention").to_i.days.ago

      Rails.logger.info { "Purging audits started before #{threshold.iso8601}" }

      Audit
        .where(started_at: ...threshold)
        .delete_all
    end
  end
end
