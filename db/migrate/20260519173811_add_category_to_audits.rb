# frozen_string_literal: true

class AddCategoryToAudits < ActiveRecord::Migration[8.0]
  def change
    add_column :audits, :category, :string, null: false, default: "connectivity"
    add_index :audits, :category
  end
end
