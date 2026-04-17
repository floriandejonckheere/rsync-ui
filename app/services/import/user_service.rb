# frozen_string_literal: true

module Import
  class UserService < BaseService
    def call
      file = path.join("01_users.csv")

      return unless file.exist?

      CSV.foreach(file, headers: true) do |row|
        User
          .create_with(
            row.to_h.slice("first_name", "last_name", "password", "role"),
          )
          .find_or_create_by!(email: row["email"])
      end
    end
  end
end
