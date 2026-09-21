# frozen_string_literal: true

class AddCategoryToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :category, :string
    add_index :servers, :category
  end
end
