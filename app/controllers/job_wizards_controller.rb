# frozen_string_literal: true

class JobWizardsController < ApplicationController
  include Wicked::Wizard

  SESSION_KEY = :job_wizard

  prepend_before_action :set_dynamic_steps

  before_action :authenticate_user!
  before_action :authorize_wizard
  before_action :guard_step!

  helper_method :wizard_summary,
                :job_form

  def show
    case step
    when :basics
      @form = JobForm.new(wizard_state.slice("name", "description", "sync_type"))
    when :source
      @form = PathForm.new(path: wizard_state["source_path"], server_id: wizard_state["source_server_id"])
      @servers = servers if job_form.remote_to_local?
    when :destination
      @form = PathForm.new(path: wizard_state["destination_path"], server_id: wizard_state["destination_server_id"])
      @servers = servers if job_form.local_to_remote?
    when :source_server, :destination_server
      @server = current_user.servers.build
    when :schedule
      @job = Job.new
    end

    render_wizard
  end

  def update
    case step
    when :basics
      update_basics
    when :source
      update_source
    when :source_server
      update_source_server
    when :destination
      update_destination
    when :destination_server
      update_destination_server
    when :schedule
      update_schedule
    end
  end

  private

  def set_dynamic_steps
    # Always present
    list = [:basics, :source]

    # Add new (source) server step if applicable
    list << :source_server unless job_form.source_server_complete?

    # Always present
    list << :destination

    # Add new (destination) server step if applicable
    list << :destination_server unless job_form.destination_server_complete?

    # Always present
    list << :schedule

    self.steps = list
  end

  def authorize_wizard
    authorize! Job.new(user: current_user), to: :create?
  end

  def guard_step!
    # Walk `steps` (built by set_dynamic_steps) in order and stop at the first one whose
    # data isn't complete yet, so users can't skip ahead via the URL. Falls through to
    # :schedule once every earlier step is complete.
    target = steps.find { |candidate| !job_form.public_send("#{candidate}_complete?") } || steps.last

    return if steps.index(step) <= steps.index(target)

    redirect_to wizard_path(target)
  end

  def wizard_state
    session[SESSION_KEY] ||= {}
  end

  def job_form
    @job_form ||= JobForm.new(wizard_state)
  end

  def wizard_summary
    return unless job_form.basics_complete?

    sync_type = I18n.t("job_wizards.form.sync_types.#{job_form.sync_type}.label")

    I18n.t("job_wizards.summary", name: job_form.name, sync_type:)
  end

  def servers
    authorized_scope(Server.order(:name), type: :relation)
  end

  def update_basics
    @form = JobForm.new(basics_params)

    if @form.valid?
      wizard_state.merge!(@form.attributes.slice("name", "description", "sync_type"))

      # Sync type may have changed which leg requires a server; drop stale server choices
      wizard_state["source_server_id"] = nil
      wizard_state["destination_server_id"] = nil
    end

    render_wizard(@form)
  end

  def basics_params
    params
      .fetch(:job_wizard, {})
      .permit(
        :name,
        :description,
        :sync_type,
      )
  end

  def update_source
    @form = build_path_form(source_params, requires_server: job_form.remote_to_local?)
    @servers = servers if job_form.remote_to_local?

    if @form.valid?
      wizard_state["source_path"] = @form.path
      wizard_state["source_server_id"] = job_form.remote_to_local? ? @form.server_id : nil

      # The next step depends on data just written above (whether a new server needs to
      # be created), so it cannot rely on wicked's `@next_step` computed from stale state
      next_step = wizard_state["source_server_id"] == PathForm::NEW_SERVER ? :source_server : :destination

      redirect_to wizard_path(next_step)
    else
      render :source,
             status: :unprocessable_content
    end
  end

  def source_params
    params
      .fetch(:job_wizard, {})
      .permit(
        :path,
        :server_id,
      )
  end

  def update_source_server
    @server = current_user.servers.build(server_params)

    if @server.save
      wizard_state["source_server_id"] = @server.id

      Servers::ConnectionJob.perform_later(@server) if Configuration.get("connectivity")
      Servers::ResourceUsageJob.perform_later(@server) if Configuration.get("resource_usage")
    end

    render_wizard(@server)
  end

  def update_destination
    @form = build_path_form(destination_params, requires_server: job_form.local_to_remote?)
    @servers = servers if job_form.local_to_remote?

    if @form.valid?
      wizard_state["destination_path"] = @form.path
      wizard_state["destination_server_id"] = job_form.local_to_remote? ? @form.server_id : nil

      # The next step depends on data just written above (whether a new server needs to
      # be created), so it cannot rely on wicked's `@next_step` computed from stale state
      next_step = wizard_state["destination_server_id"] == PathForm::NEW_SERVER ? :destination_server : :schedule

      redirect_to wizard_path(next_step)
    else
      render :destination,
             status: :unprocessable_content
    end
  end

  def destination_params
    params
      .fetch(:job_wizard, {})
      .permit(
        :path,
        :server_id,
      )
  end

  def update_destination_server
    @server = current_user.servers.build(server_params)

    if @server.save
      wizard_state["destination_server_id"] = @server.id

      Servers::ConnectionJob.perform_later(@server) if Configuration.get("connectivity")
      Servers::ResourceUsageJob.perform_later(@server) if Configuration.get("resource_usage")
    end

    render_wizard(@server)
  end

  def build_path_form(attributes, requires_server:)
    form = PathForm.new(attributes)

    form.requires_server = requires_server
    form.server_ids = current_user.servers.ids

    form
  end

  def server_params
    params
      .fetch(:job_wizard, {})
      .permit(
        :name,
        :description,
        :path,
        :operating_system,
        :host,
        :port,
        :username,
        :password,
        :ssh_key,
      )
  end

  def update_schedule
    @job = build_job(schedule_params)

    if @job.valid? && @job.save
      session.delete(SESSION_KEY)

      redirect_to jobs_path, notice: t("job_wizards.update.success")
    else
      render :schedule,
             status: :unprocessable_content
    end
  end

  def schedule_params
    permitted = params
      .fetch(:job_wizard, {})
      .permit(
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
        :opt_progress2,
        :opt_no_inc_recursive,
        :opt_superuser,
        :opt_arguments,
        :opt_local_rsync_path,
        :opt_remote_rsync_path,
        :opt_ssh_arguments,
        opt_include: [],
        opt_exclude: [],
      )

    permitted[:opt_include] = permitted.fetch(:opt_include, []).compact_blank
    permitted[:opt_exclude] = permitted.fetch(:opt_exclude, []).compact_blank

    permitted
  end

  def build_job(attributes)
    current_user.jobs.build(
      attributes.to_h.merge(
        name: job_form.name,
        description: job_form.description,
        source_repository: build_repository(:source),
        destination_repository: build_repository(:destination),
      ),
    )
  end

  def build_repository(direction)
    remote = direction == :source ? job_form.remote_to_local? : job_form.local_to_remote?

    current_user.repositories.build(
      name: I18n.t("job_wizards.repository_name.#{direction}", job_name: job_form.name),
      repository_type: remote ? "remote" : "local",
      server_id: remote ? job_form.public_send("#{direction}_server_id") : nil,
      path: job_form.public_send("#{direction}_path"),
    )
  end
end
