# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ActionPolicy::Controller
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  verify_authorized

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authorize_mission_control, if: :mission_control_controller?
  before_action :ensure_onboarded!

  skip_after_action :verify_authorized, if: :devise_controller?
  skip_after_action :verify_authorized, if: :mission_control_controller?

  authorize :user, through: :current_user

  rescue_from ActionPolicy::Unauthorized do
    redirect_to root_path, alert: I18n.t("action_policy.unauthorized"), status: :forbidden
  end

  def after_sign_in_path_for(resource)
    return configurations_path if resource.respond_to?(:admin?) && resource.admin?

    root_path
  end

  def mission_control_controller?
    is_a? ::MissionControl::Jobs::ApplicationController
  end

  def authorize_mission_control
    authorize! :monitoring
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  def ensure_onboarded!
    return unless user_signed_in?
    return if current_user.admin?
    return if current_user.onboarded_at?
    return if devise_controller?
    return if mission_control_controller?
    return if instance_of?(LandingController)
    return if instance_of?(OnboardingController)

    redirect_to onboarding_path(:profile)
  end
end
