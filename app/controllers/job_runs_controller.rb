# frozen_string_literal: true

class JobRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_run, only: [:destroy, :cancel]

  def index
    @job_runs = authorized_scope(
      JobRun.includes(job: [:source_repository, :destination_repository]).order(created_at: :desc),
      type: :relation,
    )

    authorize! :job_run
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
