# frozen_string_literal: true

module Notifications
  class SendService < NotificationService
    attr_reader :job_run,
                :event

    def initialize(notification, job_run, event, timeout: default_timeout)
      super(notification, timeout:)

      @job_run = job_run
      @event = event
    end

    def call
      rendered = RenderService
        .new(job_run, event)
        .call

      result = call_apprise(
        "--input-format=markdown",
        "--title=#{rendered[:title]}",
        "--body=#{rendered[:body]}",
        "--notification-type=#{rendered[:notification_type]}",
        notification.url,
      )

      if result[:error]
        { success: false, output: result[:error] }
      else
        { success: result[:status].success?, output: "#{result[:stdout]}\n#{result[:stderr]}".strip }
      end
    end

    protected

    def default_timeout
      30
    end
  end
end
