# frozen_string_literal: true

class JobRunsController < ApplicationController
  include Filterable
  include Sortable

  before_action :authenticate_user!
  before_action :set_job_run, only: [:show, :output, :destroy, :cancel]

  def index
    @jobs = authorized_scope(Job.order(:name), type: :relation)

    scope = authorized_scope(
      JobRun.includes(job: [:source_repository, :destination_repository]).all,
      type: :relation,
    )
    scope = scope.by_job(@filters[:job_id])
    scope = scope.by_trigger(@filters[:trigger])
    scope = scope.by_status(@filters[:status])
    scope = scope.started_from(parse_datetime(@filters[:started_at_from]))
    scope = scope.started_to(parse_datetime(@filters[:started_at_to]))
    scope = sort_for(scope, allowed: ["sequence", "status", "started_at", "completed_at"], default: { sequence: :desc })

    @pagy, @job_runs = pagy(scope)

    authorize! :job_run
  end

  def show
    authorize! @job_run
  end

  def output
    authorize! @job_run

    return head :not_found unless @job_run.output.attached? || @job_run.errored?

    filename = [
      "job",
      @job_run.sequence,
      @job_run.job.name.titleize,
      @job_run.started_at&.iso8601,
    ].compact.join("-").concat(".log")

    if @job_run.output.attached?
      redirect_to rails_blob_path(@job_run.output, disposition: "attachment; filename=\"#{filename}\""), allow_other_host: true
    else
      content = [
        @job_run.error_class.presence,
        @job_run.error_messages.presence,
      ].compact.join("\n")

      send_data content, filename:, type: "text/plain", disposition: "attachment"
    end
  end

  def create
    job = Job.find(params[:job_id])

    job_run = job
      .job_runs
      .build(user: current_user, trigger: "manual", status: "pending")

    authorize! job_run

    return head :unprocessable_content unless job.enabled?

    job_run.save!

    Jobs::ExecuteJob.perform_later(job_run)

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

    result = JobRuns::CancelService
      .new(@job_run)
      .call

    return head :unprocessable_content unless result[:success]

    redirect_to job_runs_path, notice: t(".success"), status: :see_other
  end

  private

  def set_job_run
    @job_run = JobRun.find(params[:id])
  end

  def filter_params
    params
      .fetch(:filter, {})
      .permit(
        :job_id,
        :trigger,
        :status,
        :started_at_from,
        :started_at_to,
      )
  end
end
