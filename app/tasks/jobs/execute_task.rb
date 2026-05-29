# frozen_string_literal: true

module Jobs
  class ExecuteTask < ApplicationTask
    def call # rubocop:disable Rails/Delegate
      Jobs::ScheduleJobsService.call
    end
  end
end
