# frozen_string_literal: true

module Categorizable
  extend ActiveSupport::Concern

  included do
    normalizes :category,
               with: ->(category) { category.strip.presence }

    # Keep records of the same category together (uncategorized first) while preserving the
    # existing sort within each category, so that groups don't interleave across pages
    scope :grouped_by_category, lambda {
      sort = order_values

      reorder(Arel.sql("#{quoted_table_name}.category ASC NULLS FIRST")).order(sort)
    }
  end

  class_methods do
    # Distinct, non-empty categories currently in use
    def categories
      where.not(category: nil).distinct.order(:category).pluck(:category)
    end
  end
end
