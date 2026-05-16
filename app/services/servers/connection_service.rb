# frozen_string_literal: true

module Servers
  class ConnectionService < SSHService
    def call
      super

      server.reload.update!(
        probed_at: Time.current,
        last_seen_at: Time.current,
        error_class: nil,
        error_message: nil,
      )

      { success: true }
    rescue StandardError => e
      server.reload.update!(
        probed_at: Time.current,
        error_class: e.class.to_s,
        error_message: e.message,
      )

      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "echo ok"
    end
  end
end
