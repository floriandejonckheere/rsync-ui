# frozen_string_literal: true

module Hooks
  class ImportService < ::ImportService
    private

    def csv_filename
      "08_hooks.csv"
    end

    def import(row)
      user = User.find_by!(email: row["user_email"])
      job = user.jobs.find_by!(name: row["job_name"])

      job
        .hooks
        .create_with(
          command: row["command"],
          arguments: row["arguments"],
          enabled: boolean_type.cast(row["enabled"]),
        )
        .find_or_create_by!(hook_type: row["hook_type"])
    end
  end
end
