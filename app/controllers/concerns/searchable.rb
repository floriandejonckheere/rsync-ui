# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  included do
    before_action :set_query
  end

  private

  def set_query
    @query = params[:query]
  end

  def search_for(scope, *fields)
    return scope if @query.blank?

    conditions = fields.map { |f| "#{f} ILIKE :query" }.join(" OR ")
    scope.where(conditions, query: "%#{scope.klass.sanitize_sql_like(@query)}%")
  end
end
