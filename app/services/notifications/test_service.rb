# frozen_string_literal: true

module Notifications
  class TestService < NotificationService
    def call
      result = call_apprise(
        "--input-format=markdown",
        "--title=#{title}",
        "--body=#{body}",
        "--notification-type=info",
        notification.url,
      )

      if result[:error]
        { success: false, message: result[:error] }
      elsif result[:status].success?
        { success: true, message: result[:stdout].strip }
      else
        { success: false, message: "#{result[:stdout]}\n#{result[:stderr]}".strip }
      end
    end

    protected

    def default_timeout
      10
    end

    private

    def title
      I18n.t("notifications.test.title_default")
    end

    def body
      I18n.t("notifications.test.body_default")
    end
  end
end
