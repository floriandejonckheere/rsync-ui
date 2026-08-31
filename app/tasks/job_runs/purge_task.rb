# frozen_string_literal: true

module JobRuns
  class PurgeTask < ApplicationTask
    def call # rubocop:disable Rails/Delegate
      PurgeService.call
    end
  end
end
