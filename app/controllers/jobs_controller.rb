# frozen_string_literal: true

class JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job, only: [:edit, :update, :destroy]
  before_action :set_repositories, only: [:new, :edit, :create, :update]

  def index
    @jobs = authorized_scope(Job.includes(:source_repository, :destination_repository).order(:name), type: :relation)

    authorize! :job
  end

  def new
    @job = current_user.jobs.build(enabled: true)

    authorize! @job

    @command = Rsync::CommandService.call(job: @job)
  end

  def edit
    authorize! @job

    @command = Rsync::CommandService.call(job: @job)
  end

  def create
    @job = current_user.jobs.build(job_params)

    authorize! @job

    if @job.save
      redirect_to jobs_path, notice: t(".success")
    else
      @command = Rsync::CommandService.call(job: @job)
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @job

    if @job.update(job_params)
      redirect_to jobs_path, notice: t(".success")
    else
      @command = Rsync::CommandService.call(job: @job)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @job

    @job.destroy!

    redirect_to jobs_path, notice: t(".success"), status: :see_other
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def set_repositories
    @repositories = authorized_scope(Repository.order(:name), type: :relation)
  end

  def job_params
    permitted = params
      .require(:job)
      .permit(
        :name,
        :description,
        :source_repository_id,
        :destination_repository_id,
        :schedule,
        :enabled,
        :opt_archive,
        :opt_recursive,
        :opt_relative,
        :opt_links,
        :opt_times,
        :opt_perms,
        :opt_owner,
        :opt_group,
        :opt_one_file_system,
        :opt_delete,
        :opt_delete_excluded,
        :opt_existing,
        :opt_ignore_existing,
        :opt_update,
        :opt_dry_run,
        :opt_inplace,
        :opt_size_only,
        :opt_progress,
        :opt_acls,
        :opt_xattrs,
        :opt_hard_links,
        :opt_devices,
        :opt_specials,
        :opt_checksum,
        :opt_compress,
        :opt_partial,
        :opt_backup,
        :opt_append,
        :opt_numeric_ids,
        :opt_itemize_changes,
        :opt_secluded_args,
        :opt_verbose,
        :opt_superuser,
        :opt_arguments,
        :opt_rsync_path,
      )

    permitted[:source_repository_id] = permitted_repository_id(permitted[:source_repository_id]) if permitted.key?(:source_repository_id)
    permitted[:destination_repository_id] = permitted_repository_id(permitted[:destination_repository_id]) if permitted.key?(:destination_repository_id)

    permitted
  end

  def permitted_repository_id(repository_id)
    return if repository_id.blank?

    @repositories.find_by(id: repository_id)&.id
  end
end
