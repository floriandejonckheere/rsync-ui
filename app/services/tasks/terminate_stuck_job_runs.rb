# frozen_string_literal: true

module Tasks
  class TerminateStuckJobRuns < ApplicationService
    def call # rubocop:disable Rails/Delegate
      Jobs::TerminateStuckService.call
    end
  end
end
