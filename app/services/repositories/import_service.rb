# frozen_string_literal: true

module Repositories
  class ImportService < ::ImportService
    private

    def csv_filename
      "03_repositories.csv"
    end

    def import(row)
      user = User.find_by!(email: row["user_email"])

      user
        .repositories
        .create_with(repository_attributes(row, user))
        .find_or_create_by!(name: row["name"])
    end

    def repository_attributes(row, user)
      row
        .to_h
        .slice("description", "path", "repository_type")
        .merge(read_only: boolean_type.cast(row["read_only"]), server: server_for(row, user))
    end

    def server_for(row, user)
      return if row["server_name"].blank?

      user.servers.find_by!(name: row["server_name"])
    end
  end
end
