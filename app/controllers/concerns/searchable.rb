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

    # Qualify the columns, as the scope might join other tables with identically named columns
    conditions = fields.map { |f| "#{scope.quoted_table_name}.#{scope.connection.quote_column_name(f)} ILIKE :query" }.join(" OR ")
    scope.where(conditions, query: "%#{scope.klass.sanitize_sql_like(@query)}%")
  end
end
