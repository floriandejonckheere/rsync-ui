# frozen_string_literal: true

module Notifications
  class RenderService < ApplicationService
    NOTIFICATION_TYPES = {
      "start" => "info",
      "success" => "success",
      "failure" => "failure",
      "canceled" => "warning",
    }.freeze

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
        notification_type: NOTIFICATION_TYPES.fetch(event),
      }
    end

    private

    def title
      I18n.t("notifications.events.#{event}.title", job: job_run.name)
    end

    def body
      ApplicationController.renderer.new(
        http_host: Rails.application.routes.default_url_options.fetch(:host, "localhost"),
        https: Rails.env.production?,
      ).render(
        partial: "notifications/templates/#{event}",
        formats: [:html],
        locals: { job_run: },
      )
    end
  end
end
