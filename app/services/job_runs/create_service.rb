# frozen_string_literal: true

module JobRuns
  class CreateService < ApplicationService
    attr_reader :job,
                :user,
                :trigger

    def initialize(job:, user:, trigger:)
      super()

      @job = job
      @user = user
      @trigger = trigger
    end

    def call
      # Generate command
      command = Rsync::CommandService
        .new(job:)
        .call

      job.job_runs.create!(
        user:,
        trigger:,
        status: "pending",
        command:,
      )
    end
  end
end
