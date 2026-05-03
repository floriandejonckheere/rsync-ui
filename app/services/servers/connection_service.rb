# frozen_string_literal: true

module Servers
  class ConnectionService < SSHService
    def call
      super

      if server.persisted?
        server.update!(
          probed_at: Time.current,
          last_seen_at: Time.current,
          error_class: nil,
          error_message: nil,
        )
      end

      { success: true }
    rescue StandardError => e
      if server.persisted?
        server.update!(
          probed_at: Time.current,
          error_class: e.class.to_s,
          error_message: e.message,
        )
      end

      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "echo ok"
    end
  end
end
