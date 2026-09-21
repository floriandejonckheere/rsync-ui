# frozen_string_literal: true

module CategoryOptions
  extend ActiveSupport::Concern

  class_methods do
    # Assign the authorized categories of the model to @categories (e.g. for a datalist)
    def categorizes(model, **)
      before_action(**) { @categories = categories_for(model) }
    end
  end

  private

  def categories_for(model)
    authorized_scope(model.all, type: :relation).categories
  end
end
