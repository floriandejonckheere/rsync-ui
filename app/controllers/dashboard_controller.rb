# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :dashboard

    @servers = current_user
      .servers
      .includes(:resource_usage)
      .order(:name)

    recent_runs = JobRun
      .where(user: current_user)
      .where(started_at: 24.hours.ago..)

    status_order = ["pending", "running", "canceling", "completed", "failed", "errored", "canceled"]

    @job_run_stats = recent_runs
      .group(:status)
      .count
      .sort_by { |status, _| status_order.index(status) || status_order.size }
      .to_h

    @health_status = if @job_run_stats.empty?
                       :unknown
                     elsif @job_run_stats.key?("failed") || @job_run_stats.key?("errored")
                       :degraded
                     else
                       :healthy
                     end

    @running_job_runs = JobRun
      .where(user: current_user, status: JobRuns::BroadcastService::LIVE_STATES)
      .includes(:job)
      .order(created_at: :asc)

    @last_job_run = JobRun
      .where(user: current_user)
      .where.not(status: JobRuns::BroadcastService::LIVE_STATES)
      .includes(:job)
      .order(created_at: :desc)
      .first

    @next_jobs = current_user
      .jobs
      .where(enabled: true)
      .where.not(schedule: nil)
      .select { |j| j.scheduled_next_run.present? }
      .sort_by(&:scheduled_next_run)
      .first(3)

    @repository_counts = current_user
      .repositories
      .group(:repository_type)
      .count
  end
end
