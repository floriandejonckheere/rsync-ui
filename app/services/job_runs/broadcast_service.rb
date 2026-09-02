# frozen_string_literal: true

module JobRuns
  class BroadcastService
    LIVE_STATES = ["pending", "running", "canceling"].freeze

    def self.broadcast_canceling(job_run)
      ActionCable.server.broadcast(
        "job_run_status_#{job_run.id}",
        {
          type: "canceling",
          status: "canceling",
          status_text: I18n.t("job_runs.status.canceling"),
        },
      )
    end

    def self.broadcast_started(job_run)
      ActionCable.server.broadcast(
        "job_run_status_#{job_run.id}",
        {
          type: "started",
          status: "running",
          status_text: I18n.t("job_runs.status.running"),
          started_at: job_run.started_at.iso8601,
        },
      )

      Turbo::StreamsChannel.broadcast_remove_to(
        "running_jobs_#{job_run.user_id}",
        target: "running-jobs-empty",
      )

      Turbo::StreamsChannel.broadcast_prepend_to(
        "running_jobs_#{job_run.user_id}",
        target: "running-job-runs",
        partial: "dashboard/cards/running_job_run",
        locals: { job_run: },
      )
    end

    def self.broadcast_progress(job_run)
      ActionCable.server.broadcast(
        "job_run_status_#{job_run.id}",
        {
          type: "progress",
          status_text: I18n.t("job_runs.status.running_progress", progress: job_run.progress),
          progress: job_run.progress,
          speed: job_run.speed,
          remaining_time: job_run.remaining_time,
          remaining_time_approximate: job_run.remaining_time_approximate,
        },
      )
    end

    def self.broadcast_status(job_run, type, content)
      ActionCable.server.broadcast(
        "job_run_logs_#{job_run.id}",
        {
          type:,
          content:,
        },
      )
    end

    def self.broadcast_complete(job_run, from: nil)
      ActionCable.server.broadcast(
        "job_run_status_#{job_run.id}",
        {
          type: "complete",
          status: job_run.status,
          status_text: I18n.t("job_runs.status.#{job_run.status}"),
          started_at: job_run.started_at&.iso8601,
          completed_at: job_run.completed_at&.iso8601,
          exit_status: job_run.exit_status,
          bytes_copied: job_run.bytes_copied,
        },
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "job_runs_#{job_run.user_id}",
        target: "job_run_#{job_run.id}",
        partial: "job_runs/job_run",
        locals: { job_run: },
      )

      return unless from.nil? || LIVE_STATES.include?(from.to_s)

      Turbo::StreamsChannel.broadcast_remove_to(
        "running_jobs_#{job_run.user_id}",
        target: "running_job_run_#{job_run.id}",
      )

      return unless JobRun.where(user_id: job_run.user_id, status: LIVE_STATES).none?

      Turbo::StreamsChannel.broadcast_append_to(
        "running_jobs_#{job_run.user_id}",
        target: "running-job-runs",
        partial: "dashboard/cards/running_jobs_empty",
      )
    end
  end
end
