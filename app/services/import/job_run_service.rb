# frozen_string_literal: true

module Import
  class JobRunService < BaseService
    private

    def csv_filename
      "05_job_runs.csv"
    end

    def import(row)
      job = Job.find_by!(name: row["job_name"])
      user = User.find_by!(email: row["user_email"])
      days_ago = row["days_ago"].to_s.to_i
      started_at = time_on_day(row["started_at"], days_ago)

      lookup = started_at ? { job:, started_at: } : { job:, trigger: row["trigger"], status: row["status"] }

      JobRun
        .create_with(job_run_attributes(row, job, user, started_at, days_ago))
        .find_or_create_by!(**lookup)
    end

    def job_run_attributes(row, job, user, started_at, days_ago)
      {
        job:,
        user:,
        trigger: row["trigger"],
        status: row["status"],
        started_at:,
        completed_at: time_on_day(row["completed_at"], days_ago),
      }
    end

    def time_on_day(value, days_ago)
      value.presence&.then do |time_string|
        time = Time.zone.parse(time_string)
        day = Time.zone.today - days_ago.days
        Time.zone.local(day.year, day.month, day.day, time.hour, time.min, time.sec)
      end
    end
  end
end
