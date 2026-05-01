# frozen_string_literal: true

class NotificationsController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :ensure_notifications_enabled
  before_action :set_notification, only: [:edit, :update, :destroy]
  before_action :set_notification_or_new, only: [:test]

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
    authorize! @notification, to: :test?

    @notification.url = params[:url] if params[:url].present?

    if @notification.url.blank?
      return render turbo_stream: turbo_stream.prepend(
        "notifications",
        partial: "shared/action_result",
        locals: {
          result: {
            success: false,
            message: t(".missing_url"),
          },
          success_message: t(".success"),
          failure_message: t(".failure"),
        },
      )
    end

    result = Notifications::TestService.call(@notification)

    render turbo_stream: turbo_stream.prepend(
      "notifications",
      partial: "shared/action_result",
      locals: {
        result:,
        success_message: t(".success"),
        failure_message: t(".failure"),
      },
    )
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def set_notification_or_new
    @notification = params[:id].present? ? Notification.find(params[:id]) : Notification.new
    @notification.user ||= current_user
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
