# frozen_string_literal: true

module Servers
  class ExportService < ::ExportService
    private

    def csv_filename
      "02_servers.csv"
    end

    def headers
      ["name", "description", "host", "port", "username", "password", "ssh_key", "probed_at", "last_seen_at", "error_class", "error_message", "user_email"]
    end

    def rows
      Server.includes(:user).find_each.map do |server|
        [
          server.name,
          server.description,
          server.host,
          server.port,
          server.username,
          server.password,
          server.ssh_key,
          server.probed_at,
          server.last_seen_at,
          server.error_class,
          server.error_message,
          server.user.email,
        ]
      end
    end
  end
end
