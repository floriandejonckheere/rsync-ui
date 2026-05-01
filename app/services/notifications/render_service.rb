# frozen_string_literal: true

module Notifications
  class RenderService < ApplicationService
    attr_reader :job_run, :event

    def initialize(job_run, event)
      super()

      @job_run = job_run
      @event = event
    end

    def call
      {
        title:,
        body:,
        notification_type: (event == "start" ? "info" : event),
      }
    end

    private

    def title
      I18n.t("notifications.events.#{event}.title", job: job_run.job.name)
    end

    def body
      ApplicationController.render(
        partial: "notifications/#{event}",
        formats: [:text],
        locals: { job_run: },
      )
    end
  end
end
