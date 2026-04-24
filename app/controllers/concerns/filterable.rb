# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  included do
    before_action :set_filters
  end

  private

  def set_filters
    @filters = filter_params
    @filters_active = @filters.values.any?(&:present?)
  end

  def filter_params
    params.fetch(:filter, {}).permit
  end

  def parse_datetime(value)
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
