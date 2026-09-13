# frozen_string_literal: true

class AddCategoryToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :category, :string
    add_index :jobs, :category
  end
end
