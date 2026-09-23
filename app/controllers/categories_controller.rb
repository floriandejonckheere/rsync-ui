# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category

  def update
    authorize! @category

    fallback_location = polymorphic_path(@category.categorizable_class)

    if @category.update(category_params)
      redirect_back_or_to fallback_location, notice: t(".success")
    else
      redirect_back_or_to fallback_location, alert: t(".error", errors: @category.errors.full_messages.to_sentence)
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params
      .require(:category)
      .permit(:name)
  end
end
