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
    @server = params[:server_id] ? Server.find(params[:server_id]) : Server.new
    @server.user ||= current_user

    authorize! @server, to: :connection?

    @server.host = params[:host].presence || @server.host
    @server.port = params[:port].presence || @server.port
    @server.username = params[:username].presence || @server.username
    @server.password = params[:password].presence || @server.password
    @server.ssh_key = params[:ssh_key].presence || @server.ssh_key

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
