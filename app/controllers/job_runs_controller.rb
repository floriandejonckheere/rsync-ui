# frozen_string_literal: true

class JobRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_run, only: [:show, :logs, :destroy, :cancel]

  def index
    @job_runs = authorized_scope(
      JobRun.includes(job: [:source_repository, :destination_repository]).order(created_at: :desc),
      type: :relation,
    )

    authorize! :job_run
  end

  def show
    authorize! @job_run

    redirect_to job_runs_path unless @job_run.output.attached?
  end

  def logs
    authorize! @job_run

    return head :not_found unless @job_run.output.attached?

    filename = [
      "job",
      @job_run.sequence,
      @job_run.job.name.titleize,
      @job_run.started_at&.iso8601,
    ].compact.join("-").concat(".log")

    redirect_to rails_blob_path(@job_run.output, disposition: "attachment; filename=\"#{filename}\""), allow_other_host: true
  end

  def create
    job = Job.find(params[:job_id])
    authorize! JobRun.new(job:)

    return head :unprocessable_content unless job.enabled?

    JobExecutionJob.perform_later(job, trigger: "manual")
    redirect_to job_runs_path, notice: t(".success")
  end

  def destroy
    authorize! @job_run

    unless @job_run.deletable?
      head :unprocessable_content
      return
    end

    @job_run.destroy!

    redirect_to job_runs_path, notice: t(".success"), status: :see_other
  end

  def cancel
    authorize! @job_run

    raise NotImplementedError
  end

  private

  def set_job_run
    @job_run = JobRun.find(params[:id])
  end
end
