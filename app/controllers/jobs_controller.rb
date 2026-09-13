# frozen_string_literal: true

class JobsController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :set_job, only: [:edit, :duplicate, :update, :destroy]
  before_action :set_repositories, only: [:new, :edit, :duplicate, :create, :update, :preview]
  before_action :set_categories, only: [:new, :edit, :duplicate, :create, :update]

  def index
    jobs = authorized_scope(Job.includes(:source_repository, :destination_repository).all, type: :relation)
    jobs = search_for(jobs, "name", "description")
    jobs = sort_for(jobs, allowed: ["name", "schedule"], default: { name: :asc })
    jobs = group_by_category(jobs)

    @pagy, @jobs = pagy(jobs)

    authorize! :job
  end

  def new
    @job = current_user.jobs.build(enabled: true)

    authorize! @job

    build_hooks(@job)

    @command = Rsync::CommandService.new(job: @job)
  end

  def edit
    authorize! @job

    build_hooks(@job)

    @command = Rsync::CommandService.new(job: @job)
  end

  def duplicate
    authorize! @job

    @job = @job.dup
    @job.name = I18n.t("jobs.duplicate.name", job_name: @job.name)

    build_hooks(@job)

    @command = Rsync::CommandService.new(job: @job)
  end

  def create
    @job = current_user.jobs.build(job_params)

    authorize! @job

    if @job.save
      redirect_to jobs_path, notice: t(".success")
    else
      @command = Rsync::CommandService.new(job: @job)

      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @job

    if @job.update(job_params)
      redirect_to jobs_path, notice: t(".success")
    else
      @command = Rsync::CommandService.new(job: @job)

      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @job

    @job.destroy!

    redirect_to jobs_path, notice: t(".success"), status: :see_other
  end

  def preview
    @job = current_user
      .jobs
      .build(job_params.except(:job_notifications_attributes, :hooks_attributes))

    authorize! @job, to: :preview?

    @command = Rsync::CommandService.new(job: @job)

    render partial: "preview"
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def set_repositories
    @repositories = authorized_scope(Repository.order(:name), type: :relation)
  end

  def set_categories
    @categories = authorized_scope(Job.all, type: :relation)
      .where.not(category: nil)
      .distinct
      .order(:category)
      .pluck(:category)
  end

  # Keep jobs of the same category together (uncategorized first) while preserving the
  # user-selected sort within each category, so that groups don't interleave across pages
  def group_by_category(scope)
    sort = scope.order_values

    scope
      .reorder(Arel.sql("jobs.category ASC NULLS FIRST"))
      .order(sort)
  end

  def job_params
    permitted = params
      .require(:job)
      .permit(
        :name,
        :description,
        :category,
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
        :opt_delete_before,
        :opt_delete_during,
        :opt_delete_delay,
        :opt_delete_after,
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
        :opt_progress2,
        :opt_no_inc_recursive,
        :opt_superuser,
        :opt_arguments,
        :opt_local_rsync_path,
        :opt_remote_rsync_path,
        :opt_ssh_arguments,
        opt_include: [],
        opt_exclude: [],
        job_notifications_attributes: [
          :id,
          :notification_id,
          :enabled,
          :on_start,
          :on_success,
          :on_failure,
          :on_canceled,
          :_destroy,
        ],
        hooks_attributes: [
          :id,
          :hook_type,
          :command,
          :arguments,
          :enabled,
          :_destroy,
        ],
      )

    permitted[:source_repository_id] = permitted_repository_id(permitted[:source_repository_id]) if permitted.key?(:source_repository_id)
    permitted[:destination_repository_id] = permitted_repository_id(permitted[:destination_repository_id]) if permitted.key?(:destination_repository_id)
    permitted[:opt_include] = permitted.fetch(:opt_include, []).compact_blank
    permitted[:opt_exclude] = permitted.fetch(:opt_exclude, []).compact_blank

    permitted
  end

  def build_hooks(job)
    return unless Configuration.get("hooks")

    ["pre", "post", "success", "failure"].each do |hook_type|
      job.hooks.find { |h| h.hook_type == hook_type } || job.hooks.build(hook_type:)
    end
  end

  def permitted_repository_id(repository_id)
    return if repository_id.blank?

    @repositories.find_by(id: repository_id)&.id
  end
end
