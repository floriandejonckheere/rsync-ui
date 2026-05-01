# frozen_string_literal: true

module Notifications
  class SendJob < ApplicationJob
    queue_as :default

    EVENT_FLAGS = {
      "start" => :on_start?,
      "success" => :on_success?,
      "failure" => :on_failure?,
    }.freeze

    def perform(job_notification_id, job_run_id, event)
      return unless Configuration.get("notifications")

      job_notification = JobNotification.find_by(id: job_notification_id)

      return if job_notification.nil?
      return unless job_notification.enabled?
      return unless job_notification.notification.enabled?
      return unless job_notification.public_send(EVENT_FLAGS.fetch(event))

      job_run = JobRun.find_by(id: job_run_id)

      return if job_run.nil?

      result = Notifications::SendService.call(job_notification.notification, job_run, event)

      Rails.logger.warn "[Notifications] delivery failed: #{result[:output]}" unless result[:success]
    end
  end
end
