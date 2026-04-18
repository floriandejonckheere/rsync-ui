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

      job_run = JobRun
        .create_with(job_run_attributes(row, job, user, started_at, days_ago))
        .find_or_create_by!(**lookup)

      attach_dummy_log(job_run, row["status"]) if ["completed", "failed"].include?(row["status"])

      job_run
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

    def attach_dummy_log(job_run, status)
      return if job_run.output.attached?

      content = dummy_log_content(job_run, status)
      job_run.output.attach(
        io: StringIO.new(content),
        filename: "output.log",
        content_type: "text/plain",
      )
    end

    def dummy_log_content(job_run, status)
      lines = [
        "rsync started at #{job_run.started_at&.iso8601}",
        "sending incremental file list",
        "data/",
        "data/backup_2024.tar.gz",
        "data/config.yml",
        "data/logs/app.log",
        "",
        "sent 1,234,567 bytes  received 892 bytes  823,639.33 bytes/sec",
        "total size is 12,345,678  speedup is 10.00",
      ]

      lines << (status == "failed" ? "rsync error: some files/attrs were not transferred (code 23)" : "rsync completed successfully")
      lines << "completed at #{job_run.completed_at&.iso8601}"

      lines.join("\n")
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
