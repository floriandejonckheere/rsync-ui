# frozen_string_literal: true

class NotificationsController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :ensure_notifications_enabled
  before_action :set_notification, only: [:edit, :update, :destroy, :test]

  def index
    notifications = authorized_scope(Notification.all, type: :relation)
    notifications = search_for(notifications, "name", "description")
    notifications = sort_for(notifications, allowed: ["name"], default: { name: :asc })

    @pagy, @notifications = pagy(notifications)

    authorize! :notification
  end

  def new
    @notification = Notification.new(enabled: true)
    @notification.user = current_user

    authorize! @notification
  end

  def edit
    authorize! @notification
  end

  def create
    @notification = current_user.notifications.build(notification_params)

    authorize! @notification

    if @notification.save
      redirect_to notifications_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @notification

    if @notification.update(update_params)
      redirect_to notifications_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @notification

    @notification.destroy!

    redirect_to notifications_path, notice: t(".success"), status: :see_other
  end

  def test
    authorize! @notification

    # Wired up in a later task; placeholder for now.
    head :not_implemented
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def ensure_notifications_enabled
    raise ActionController::RoutingError, "Not Found" unless Configuration.get("notifications")
  end

  def notification_params
    params.require(:notification).permit(:name, :description, :url, :enabled)
  end

  def update_params
    permitted = notification_params
    permitted.delete(:url) if permitted[:url].blank?
    permitted
  end
end
