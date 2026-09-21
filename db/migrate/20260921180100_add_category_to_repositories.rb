# frozen_string_literal: true

class AddCategoryToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :category, :string
    add_index :repositories, :category
  end
end
