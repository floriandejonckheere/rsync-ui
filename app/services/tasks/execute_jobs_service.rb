# frozen_string_literal: true

module Tasks
  class ExecuteJobsService < ApplicationService
    delegate :call, to: Jobs::ScheduleJobsService
  end
end
