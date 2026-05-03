# frozen_string_literal: true

module Jobs
  class ImportService < ::ImportService
    private

    def csv_filename
      "04_jobs.csv"
    end

    def import(row)
      user = User.find_by!(email: row["user_email"])

      user
        .jobs
        .create_with(job_attributes(row, user))
        .find_or_create_by!(name: row["name"])
    end

    def job_attributes(row, user)
      row
        .to_h
        .slice("description", "schedule")
        .merge(
          enabled: boolean_type.cast(row["enabled"]),
          source_repository: repository_for(row["source_repository_name"], user),
          destination_repository: repository_for(row["destination_repository_name"], user),
        )
    end

    def repository_for(name, user)
      user.repositories.find_by!(name:)
    end
  end
end
