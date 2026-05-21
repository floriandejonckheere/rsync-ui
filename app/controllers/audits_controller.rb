# frozen_string_literal: true

class AuditsController < ApplicationController
  include Filterable
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :ensure_audits_enabled
  before_action :set_audit, only: [:show]

  def index
    @servers = authorized_scope(Server.order(:name), type: :relation)
    @categories = Audit.categories.keys
    @default_categories = ["connectivity", "job", "resource_usage"]

    scope = authorized_scope(Audit.includes(:server).all, type: :relation)
    scope = search_for(scope, "command")

    scope = scope.by_server(@filters[:server_id])

    scope = scope.completed if @filters[:exit_status] == "completed"
    scope = scope.failed if @filters[:exit_status] == "failed"

    scope = scope.started_from(parse_datetime(@filters[:started_at_from]))
    scope = scope.started_to(parse_datetime(@filters[:started_at_to]))

    @selected_categories = begin
      JSON.parse(@filters[:categories] || @default_categories.to_json)
    rescue StandardError
      @default_categories
    end
    scope = scope.by_category(@selected_categories) if @selected_categories.present?

    scope = sort_for(scope, allowed: ["started_at", "completed_at"], default: { started_at: :desc })

    @pagy, @audits = pagy(scope)

    authorize! :audit
  end

  def show
    authorize! @audit
  end

  private

  def set_audit
    @audit = Audit.find(params[:id])
  end

  def ensure_audits_enabled
    raise ActionController::RoutingError, "Not Found" unless Configuration.get("audits")
  end

  def filter_params
    params
      .fetch(:filter, {})
      .permit(
        :server_id,
        :exit_status,
        :started_at_from,
        :started_at_to,
        :categories,
      )
  end
end
