# frozen_string_literal: true

class ServersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server, only: [:edit, :update, :destroy]

  def index
    @pagy, @servers = pagy(authorized_scope(Server.order(:name), type: :relation))

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

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params
      .require(:server)
      .permit(:name, :description, :host, :port, :username, :password, :ssh_key)
  end

  def update_params
    permitted = server_params
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:ssh_key) if permitted[:ssh_key].blank?
    permitted
  end
end
