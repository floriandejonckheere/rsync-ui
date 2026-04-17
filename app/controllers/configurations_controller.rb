# frozen_string_literal: true

class ConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_configuration, only: [:update]

  def index
    @configurations = authorized_scope(Configuration.order(:key), type: :relation)

    authorize! :configuration
  end

  def update
    authorize! @configuration

    notice = if @configuration.update(update_params)
               I18n.t("configurations.update.success")
             else
               I18n.t("configurations.update.error")
             end

    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.replace(
          @configuration,
          partial: "configurations/configuration",
          locals: { configuration: @configuration },
        )]

        all_dependent_configurations.each do |dependent|
          streams << turbo_stream.replace(
            dependent,
            partial: "configurations/configuration",
            locals: { configuration: dependent },
          )
        end

        render turbo_stream: streams
      end
      format.html { redirect_to configurations_path, notice: }
    end
  end

  private

  def set_configuration
    @configuration = Configuration.find(params[:id])
  end

  def all_dependent_configurations
    @configuration.all_dependents.filter_map do |key|
      Configuration.find_by(key:)
    end
  end

  def update_params
    params
      .require(:configuration)
      .permit(:value)
  end
end
