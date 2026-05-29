# frozen_string_literal: true

module JobRuns
  class TerminateStuckTask < ApplicationTask
    def call # rubocop:disable Rails/Delegate
      TerminateStuckService.call
    end
  end
end
