# frozen_string_literal: true

module Tasks
  class ExecuteService < ApplicationService
    attr_reader :task,
                :user

    def initialize(task, user:)
      super()

      @task = task
      @user = user
    end

    def call
      task.update!(
        status: "running",
        last_run_at: Time.zone.now,
        last_run_by_id: user.id,
        error_class: nil,
        error_message: nil,
      )

      task
        .class_name
        .constantize
        .call

      task.update!(status: "completed")

      { success: true }
    rescue StandardError => e
      task.update!(
        status: "failed",
        error_class: e.class.name,
        error_message: e.message,
      )

      { success: false, message: "#{e.class}: #{e.message}" }
    end
  end
end
