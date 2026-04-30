# frozen_string_literal: true

class ServersController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :set_server, only: [:edit, :update, :destroy]

  def index
    servers = authorized_scope(Server.includes(:resource_usage), type: :relation)
    servers = search_for(servers, "name", "description", "host")
    servers = sort_for(servers, allowed: ["name", "host"], default: { name: :asc })

    @pagy, @servers = pagy(servers)

    authorize! :server
  end

  def new
    @server = Server.new

    authorize! @server
  end

  def edit
    authorize! @server
  end

  def create
    @server = current_user.servers.build(server_params)

    authorize! @server

    if @server.save
      redirect_to servers_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @server

    if @server.update(update_params)
      redirect_to servers_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @server

    @server.destroy!

    redirect_to servers_path, notice: t(".success"), status: :see_other
  end

  def connection
    @server = params[:server_id].present? ? Server.find(params[:server_id]) : Server.new
    @server.user ||= current_user

    authorize! @server, to: :connection?

    @server.host = params[:host] if params[:host].present?
    @server.port = params[:port] if params[:port].present?
    @server.username = params[:username] if params[:username].present?
    @server.password = params[:password] if params[:password].present?
    @server.ssh_key = params[:ssh_key] if params[:ssh_key].present?

    if @server.host.blank? || @server.port.blank? || @server.username.blank? || (@server.password.blank? && @server.ssh_key.blank?)
      return render turbo_stream: turbo_stream.prepend(
        "notifications",
        partial: "servers/connection_result",
        locals: { result: { success: false, message: t(".missing_details") } },
      )
    end

    result = Servers::ConnectionService.call(@server)

    render turbo_stream: turbo_stream.prepend(
      "notifications",
      partial: "servers/connection_result",
      locals: { result: },
    )
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params
      .require(:server)
      .permit(
        :name,
        :description,
        :path,
        :host,
        :port,
        :username,
        :password,
        :ssh_key,
      )
  end

  def update_params
    permitted = server_params
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:ssh_key) if permitted[:ssh_key].blank?
    permitted
  end
end
