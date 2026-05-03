# frozen_string_literal: true

module Notifications
  class ImportService < ::ImportService
    private

    def csv_filename
      "06_notifications.csv"
    end

    def import(row)
      user = User.find_by!(email: row["user_email"])

      user
        .notifications
        .create_with(
          row.to_h.slice("description", "url")
            .merge(enabled: boolean_type.cast(row["enabled"])),
        )
        .find_or_create_by!(name: row["name"])
    end
  end
end
