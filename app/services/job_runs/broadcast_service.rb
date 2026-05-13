# frozen_string_literal: true

module JobRuns
  class BroadcastService
    LIVE_STATES = ["pending", "running"].freeze

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
        },
      )
    end

    def self.broadcast_complete(job_run, from: nil)
      helpers = ActionController::Base.helpers

      ActionCable.server.broadcast(
        "job_run_status_#{job_run.id}",
        {
          type: "complete",
          status: job_run.status,
          status_text: I18n.t("job_runs.status.#{job_run.status}"),
          started_at: job_run.started_at&.iso8601,
          completed_at: job_run.completed_at&.iso8601,
          duration: job_run.started_at ? helpers.distance_of_time_in_words(job_run.started_at, job_run.completed_at || Time.zone.now) : nil,
        },
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
