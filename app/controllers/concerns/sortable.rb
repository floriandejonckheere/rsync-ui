# frozen_string_literal: true

module Sortable
  extend ActiveSupport::Concern

  included do
    before_action :set_sort
  end

  private

  def set_sort
    @sort_column = params[:sort].presence
    @sort_direction = params[:direction].in?(["asc", "desc"]) ? params[:direction] : nil
    @sort_column = nil unless @sort_direction
  end

  def sort_for(scope, allowed:, default:)
    if @sort_column&.in?(allowed.map(&:to_s)) && @sort_direction
      @active_sort_column = @sort_column
      @active_sort_direction = @sort_direction
      scope.reorder(@sort_column => @sort_direction)
    else
      @active_sort_column = default.keys.first.to_s
      @active_sort_direction = default.values.first.to_s
      scope.reorder(default)
    end
  end
end
