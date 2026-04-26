# frozen_string_literal: true

module Servers
  class ConnectionService < SSHService
    def call
      super

      { success: true }
    rescue StandardError => e
      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "echo ok"
    end
  end
end
