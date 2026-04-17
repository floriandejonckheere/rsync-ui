# frozen_string_literal: true

module Import
  class ServerService < BaseService
    def call
      file = path.join("02_servers.csv")

      return unless file.exist?

      CSV.foreach(file, headers: true) do |row|
        user = User.find_by!(email: row["user_email"])

        user
          .servers
          .create_with(
            row.to_h.slice("description", "host", "port", "username", "password", "ssh_key"),
          )
          .find_or_create_by!(name: row["name"])
      end
    end
  end
end
