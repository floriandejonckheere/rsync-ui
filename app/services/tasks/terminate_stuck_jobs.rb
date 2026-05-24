# frozen_string_literal: true

module Tasks
  class TerminateStuckJobs < ApplicationService
    def call # rubocop:disable Rails/Delegate
      Jobs::TerminateStuckJobsService.call
    end
  end
end
