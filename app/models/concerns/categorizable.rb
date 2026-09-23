# frozen_string_literal: true

module Categorizable
  extend ActiveSupport::Concern

  included do
    belongs_to :category,
               optional: true,
               autosave: true

    before_validation :assign_category,
                      if: -> { instance_variable_defined?(:@category_name) }

    after_save :destroy_unused_category,
               if: :saved_change_to_category_id?

    after_destroy :destroy_unused_category

    # Keep records of the same category together (uncategorized first) while preserving the
    # existing sort within each category, so that groups don't interleave across pages
    scope :grouped_by_category, lambda {
      sort = order_values

      left_joins(:category)
        .preload(:category)
        .reorder(Category.arel_table[:name].asc.nulls_first, Category.arel_table[:id].asc)
        .order(sort)
    }
  end

  def category_name
    return @category_name.strip.presence if instance_variable_defined?(:@category_name)

    category&.name
  end

  # Assign a category by name: an existing category of the owner is reused (case-insensitively),
  # otherwise a new one is created. A blank name removes the category.
  def category_name=(name)
    @category_name = name.to_s
  end

  private

  def assign_category
    name = category_name

    remove_instance_variable(:@category_name)

    self.category = name && Category
      .named(name)
      .find_or_initialize_by(user:, categorizable_type: self.class.name) { |category| category.name = name }
  end

  def destroy_unused_category
    category_id = destroyed? ? self.category_id : category_id_before_last_save
    category = Category.find_by(id: category_id)

    category.destroy! if category && !category.records.exists?
  end
end
