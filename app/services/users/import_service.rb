# frozen_string_literal: true

module Users
  class ImportService < ::ImportService
    private

    def csv_filename
      "01_users.csv"
    end

    def import(row)
      User
        .create_with(
          row.to_h.slice("first_name", "last_name", "password", "role"),
        )
        .find_or_create_by!(email: row["email"])
    end
  end
end
