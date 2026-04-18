# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_repository, only: [:edit, :update, :destroy]
  before_action :set_servers, only: [:new, :edit, :create, :update]

  def index
    @pagy, @repositories = pagy(authorized_scope(Repository.order(:name), type: :relation))

    authorize! :repository
  end

  def new
    @repository = Repository.new(repository_type: "local")

    authorize! @repository
  end

  def edit
    authorize! @repository
  end

  def create
    @repository = current_user.repositories.build(repository_params)

    authorize! @repository

    if @repository.save
      redirect_to repositories_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @repository

    if @repository.update(repository_params)
      redirect_to repositories_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @repository

    @repository.destroy!

    redirect_to repositories_path, notice: t(".success"), status: :see_other
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def set_servers
    owner = @repository&.user || current_user
    @servers = owner.servers.order(:name)
  end

  def repository_params
    permitted = params
      .require(:repository)
      .permit(:name, :description, :repository_type, :server_id, :path, :read_only)

    permitted[:server_id] = nil if permitted[:repository_type] == "local"
    permitted
  end
end
