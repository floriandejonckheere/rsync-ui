# frozen_string_literal: true

module Import
  class ServerService < BaseService
    private

    def csv_filename
      "02_servers.csv"
    end

    def import(row)
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
